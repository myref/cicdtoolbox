#!/bin/bash

# Started with sh -c "portainer/install.sh"

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
echo " Ensure reachability of Portainer"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "portainer" /etc/hosts; then
    sudo sed -i "/portainer.monitoring.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.13.3   portainer.monitoring.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   portainer.monitoring.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Add Portainer to Keycloak"
echo "****************************************************************************************************************"
docker cp portainer/add_portainer_to_realm.sh keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/keycloak/bin/add_portainer_to_realm.sh
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/add_portainer_to_realm.sh ${local_admin_user} ${local_admin_password}" | tee install/log/keycloak_portainer_create.log
echo " "
echo "****************************************************************************************************************"
echo " Starting Portainer"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps portainer
let t=0
until $(curl --output /dev/null --insecure --silent --head --fail http://portainer.monitoring.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:9000); do
    spin
done
endspin
echo "****************************************************************************************************************"
echo " Configuring Portainer"
echo "****************************************************************************************************************"
robot -d install/log -o 20_configure_portainer.xml -l 20_configure_portainer_log.html -r 20_configure_portainer_report.html portainer/configure_portainer.robot
 