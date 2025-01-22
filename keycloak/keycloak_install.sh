#!/bin/bash

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
echo " Ensure reachability of Keycloak through the hosts file"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "keycloak" /etc/hosts; then
    echo " Keycloak exists in /etc/hosts, removing..."
    sudo sed -i '/keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts
fi
echo " Add Keycloak to /etc/hosts"
sudo echo "172.16.10.11   keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Starting Keycloak "
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
echo "****************************************************************************************************************"
echo " Wait until keycloak is running (~45 sec.)"
echo "****************************************************************************************************************"
let t=0
until $(curl --output /dev/null --silent --head --fail https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443); do
    spin
done
endspin
echo " "
echo "****************************************************************************************************************"
echo " Creating keycloak setup. This will take time..."
echo "****************************************************************************************************************"
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/create-realm.sh ${keycloak_pwd} ${keycloak_storepass} ${keycloak_pwd} ${local_admin_user}" | tee install_log/keycloak_create.log
echo " "
docker restart keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
echo "****************************************************************************************************************"
echo " Wait until keycloak is running (~5 sec.)"
echo "****************************************************************************************************************"
let t=0
until $(curl --output /dev/null --silent --head --fail https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443); do
    spin
done
endspin
echo " "
