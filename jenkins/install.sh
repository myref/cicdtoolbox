#!/bin/bash

# Started with sh -c "install.sh ${jenkins_storepass}"

sp="/-\|"
sc=0
spin() {
   printf -- "${sp:sc++:1}  ( ${t} sec.) \r"
   ((sc==${#sp})) && sc=0
   sleep 1
   let t+=1
}

endspin() {
   printf "\r%s\n" "$@"
}

echo "****************************************************************************************************************"
echo " Cleaning Jenkins" 
echo "****************************************************************************************************************"
rm -f jenkins/jenkins.tooling*
cp jenkins/casc.yaml.template jenkins/casc.yaml
echo " " 
echo "****************************************************************************************************************"
echo " Cleaning Jenkins buildnodes" 
echo "****************************************************************************************************************"
rm -f buildnode/*_secret.txt
rm -f buildnode/agent.jar
rm -f buildnode/jenkins-cli.jar
rm -f buildnode/*_token
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of Jenkins"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "jenkins" /etc/hosts; then
    sudo sed -i "/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.11.8   jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Copying Jenkins certificates"
echo "****************************************************************************************************************"
cp vault/certs/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem jenkins/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem
cp vault/certs/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt jenkins/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt
cp vault/certs/ca.crt jenkins/ca.crt
echo "****************************************************************************************************************"
echo " Copy certificates into Jenkins keystore"
echo "****************************************************************************************************************"
cat jenkins/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt jenkins/ca.crt > jenkins/import.pem
openssl pkcs12 -export -in jenkins/import.pem -inkey jenkins/jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem -name jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem -passout pass:$jenkins_storepass > jenkins/jenkins.p12
#Import the PKCS12 file into Java keystore:
keytool -importkeystore -srckeystore jenkins/jenkins.p12 -destkeystore jenkins/keystore/jenkins.jks -srcstoretype pkcs12 -srcstorepass $jenkins_storepass -storepass $jenkins_storepass -noprompt -deststoretype pkcs12
echo "****************************************************************************************************************"
echo " Configuring pipeline"
echo "****************************************************************************************************************"
echo " " 
rm -f jenkins/org_name/config.xml
cp jenkins/org_name/config.xml.template jenkins/org_name/config.xml
sed -i -e "s/ORG_NAME/${ORG_NAME}/g" jenkins/org_name/config.xml
sed -i -e "s/provider/${DOMAIN_NAME_SL}/g" jenkins/org_name/config.xml
sed -i -e "s/test/${DOMAIN_NAME_TL}/g" jenkins/org_name/config.xml
echo "****************************************************************************************************************"
echo " Starting jenkins"
echo "****************************************************************************************************************"
echo " " 
docker compose --project-name cicd-toolbox up -d --build --no-deps jenkins
echo "****************************************************************************************************************"
echo " We need a hack to get the CA into Jenkins"
echo "****************************************************************************************************************"
sleep 2
echo " " 
echo "****************************************************************************************************************"
echo " Copy CA certificates into Jenkins keystore"
echo "****************************************************************************************************************"
docker cp jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/java/openjdk/lib/security/cacerts ./jenkins/keystore/cacerts
chmod +w ./jenkins/keystore/cacerts
keytool -import -alias vault.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} -keystore ./jenkins/keystore/cacerts -file ./jenkins/ca.crt -storepass $jenkins_storepass -noprompt
docker cp ./jenkins/keystore/cacerts jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/java/openjdk/lib/security/cacerts
echo " " 
echo "****************************************************************************************************************"
echo " putting Jenkins secret in casc file"
echo "****************************************************************************************************************"
#config for oic_auth plugin: need to replace secrets in casc.yaml
jenkins_client_id=$(grep JENKINS_token: install/log/keycloak_create.log | cut -d' ' -f2 | tr -d '\r' )
docker exec -it jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "sed -i -e 's/oic_secret/\"${jenkins_client_id}\"/' /var/jenkins_conf/casc.yaml"
echo " " 
echo "****************************************************************************************************************"
echo " Restarting Jenkins"
echo "****************************************************************************************************************"
docker restart jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
let t=0
until $(curl --output /dev/null --insecure --silent --head --fail https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/whoAmI); do
    spin
done
endspin
echo " " 
echo "****************************************************************************************************************"
echo " Downloading agent.jar from jenkins"
echo "****************************************************************************************************************"
if $(curl --output /dev/null --insecure --silent --head --fail https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/whoAmI); then
    wget --no-check-certificate https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/jnlpJars/agent.jar
    mv agent.jar buildnode/agent.jar
    echo "Retrieved agent.jar from Jenkins and copied to buildnode."
else
    echo "Jenkins not running, no recent agent present"
fi
echo " "
echo "****************************************************************************************************************"
echo " Copying Jenkins Keystore to Jenkins buildnodes"
echo "****************************************************************************************************************"
cp ./jenkins/keystore/cacerts ./buildnode/cacerts
echo "****************************************************************************************************************"
echo " Configuring Jenkins for jenkins-jenkins login and storing token"
echo "****************************************************************************************************************"
robot -d install/log -o 20_configure_jenkins.xml -l 20_configure_jenkins_log.html -r 20_configure_jenkins_report.html jenkins/configure_jenkins.robot
echo " " 
echo "****************************************************************************************************************"
echo " Creating active casc file"
echo "****************************************************************************************************************"
robot -d install/log -o 21_save_jenkins_config.xml -l 21_save_jenkins_config_log.html -r 21_save_jenkins_config_report.html jenkins/save_config.robot
echo "****************************************************************************************************************"
echo " Updating remote casc file"
echo "****************************************************************************************************************"
docker cp jenkins/casc.yaml jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/var/jenkins_conf/casc.yaml 
echo "****************************************************************************************************************"
echo " Building build nodes"
echo "****************************************************************************************************************"
buildnode/install.sh | tee install/log/buildnode_create.log
