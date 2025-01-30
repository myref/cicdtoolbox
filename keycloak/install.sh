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
echo " Ensure reachability of Keycloak"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "keycloak" /etc/hosts; then
    sudo sed -i "/keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.10.11   keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Starting Keycloak "
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps keycloak
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
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/create-realm.sh ${local_admin_password} ${keycloak_storepass} ${local_admin_password} ${local_admin_user}" | tee install/log/keycloak_create.log
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
