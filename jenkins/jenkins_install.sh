#!/bin/bash

# Started with sh -c "jenkins-install.sh ${jenkins_storepass}"

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
pwd 
echo $jenkins_storepass
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
jenkins_client_id=$(grep JENKINS_token: install_log/keycloak_create.log | cut -d' ' -f2 | tr -d '\r' )
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
    mv agent.jar jenkins_buildnode/agent.jar
    echo "Retrieved agent.jar from Jenkins and copied to buildnode."
else
    echo "Jenkins not running, no recent agent present"
fi
echo " "
echo "****************************************************************************************************************"
echo " Copying Jenkins Keystore to Jenkins buildnodes"
echo "****************************************************************************************************************"
cp ./jenkins/keystore/cacerts ./jenkins_buildnode/cacerts
echo "****************************************************************************************************************"
echo " Configuring Jenkins for jenkins-jenkins login and storing token"
echo "****************************************************************************************************************"
robot --variable VALID_PASSWORD:$netcicd_pwd -d install_log -o 20_configure_jenkins.xml -l 20_configure_jenkins_log.html -r 20_configure_jenkins_report.html jenkins/configure_jenkins.robot
echo "****************************************************************************************************************"
echo " Retrieving Jenkins CSRF"
echo "****************************************************************************************************************"
if [ -f "jtoken.txt" ]; then
    echo "Token exists"
    jtoken=$(cat jtoken.txt)
    echo "jtoken: ${jtoken}"
    echo "****************************************************************************************************************"
    echo " Wait until we can retrieve the CSRF"
    echo "****************************************************************************************************************"

    if curl -u "jenkins-jenkins:${jtoken}" --insecure 'https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)'; then
        crumb=$(curl -u "jenkins-jenkins:${jtoken}" --insecure 'https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')
        echo "crumb: ${crumb}"
        csrf=$( echo $crumb | awk -F',' '{print $(1)}' | awk -F':' '{print $2}' )
        echo "csrf: ${csrf}"
        #rm -f jtoken.txt
    else
        echo "No crumb!"
        #exit 1
    fi

else
    echo " No token, aborting"
    #exit 1
fi
echo " " 
echo "****************************************************************************************************************"
echo " Retrieving Jenkins Agent secrets"
echo "****************************************************************************************************************"
curl -L --insecure -u "jenkins-jenkins:${jtoken}" -H "Jenkins-Crumb:${csrf}" https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/computer/Dev/jenkins-agent.jnlp -s | sed "s/.*<jnlp><application-desc><argument>\([a-z0-9]*\).*/\1/" > jenkins_buildnode/Dev_secret.txt
echo "dev: " 
cat jenkins_buildnode/Dev_secret.txt
echo "" 
curl -L --insecure -u "jenkins-jenkins:${jtoken}" -H "Jenkins-Crumb:${csrf}" https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/computer/Acc/jenkins-agent.jnlp -s | sed "s/.*<jnlp><application-desc><argument>\([a-z0-9]*\).*/\1/" > jenkins_buildnode/Acc_secret.txt
echo "acc: " 
cat jenkins_buildnode/Acc_secret.txt
echo "" 
curl -L --insecure -u "jenkins-jenkins:${jtoken}" -H "Jenkins-Crumb:${csrf}" https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/computer/Test/jenkins-agent.jnlp -s | sed "s/.*<jnlp><application-desc><argument>\([a-z0-9]*\).*/\1/" > jenkins_buildnode/Test_secret.txt
echo "test: " 
cat jenkins_buildnode/Test_secret.txt
echo "" 
curl -L --insecure -u "jenkins-jenkins:${jtoken}" -H "Jenkins-Crumb:${csrf}" https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/computer/Prod/jenkins-agent.jnlp -s | sed "s/.*<jnlp><application-desc><argument>\([a-z0-9]*\).*/\1/" > jenkins_buildnode/Prod_secret.txt
echo "prod: " 
cat jenkins_buildnode/Prod_secret.txt
echo "" 
echo "****************************************************************************************************************"
echo " Building build nodes"
echo "****************************************************************************************************************"
jenkins_buildnode/create_runner.sh ${netcicd_pwd} | tee install_log/buildnode_create.log
