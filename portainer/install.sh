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
echo " Configuring Keycloak for Portainer"
echo "****************************************************************************************************************"
docker cp portainer/realm_add_portainer.sh keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/keycloak/bin/realm_add_portainer.sh
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chmod +x /opt/keycloak/bin/realm_add_portainer.sh" | tee install/log/keycloak_portainer_create.log
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/realm_add_portainer.sh ${local_admin_user} ${local_admin_password}" | tee install/log/keycloak_portainer_create.log
echo " "
echo "****************************************************************************************************************"
echo " Starting Portainer"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps portainer