#!/bin/bash

print_random () {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32
}
echo "****************************************************************************************************************"
echo " Cleaning CUST1-IDP" 
echo "****************************************************************************************************************"
rm -f cust1_idp/data/*.crt
rm -rf cust1_idp/data/*.pem
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of CUST1-IDP"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "cust1-idp" /etc/hosts; then
    sudo sed -i "/cust1-idp.iam.${CUST1_DOMAIN_NAME_SL}.${CUST1_DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.8.110   cust1-idp.iam.${CUST1_DOMAIN_NAME_SL}.${CUST1_DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   cust1-idp.iam.${CUST1_DOMAIN_NAME_SL}.${CUST1_DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Add cust1-idp to keycloak"
echo "****************************************************************************************************************"
docker cp cust1_idp/add_cust1_idp_to_realm.sh keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/keycloak/bin/add_cust1_idp_to_realm.sh
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/add_cust1_idp_to_realm.sh ${local_admin_user} ${local_admin_password} ${local_admin_password}" | tee install/log/keycloak_cust1_idp_create.log
echo " "
echo "****************************************************************************************************************"
echo " Creating CUST1-IDP secrets" 
echo "****************************************************************************************************************"
export CUST1_IDP_JWT_SECRET=$(print_random)
export CUST1_IDP_KEY_SEED=$(print_random)
echo "****************************************************************************************************************"
echo " Starting CUST1-IDP"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --remove-orphans cust1_idp
echo " "
echo "****************************************************************************************************************"
echo " Adding users and groups to CUST1-IDP server" 
echo "****************************************************************************************************************"
docker compose exec cust1_idp /bootstrap/bootstrap.sh
echo " "
