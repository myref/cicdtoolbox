#!/bin/bash

print_random () {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32
}
echo "****************************************************************************************************************"
echo " Cleaning LLDAP" 
echo "****************************************************************************************************************"
rm -f lldap/data/*.crt
rm -rf lldap/data/*.pem
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of LDAP"
echo "****************************************************************************************************************"
if grep -q "ldap" /etc/hosts; then
    if [ "$install_mode" = "vm" ]; then
        echo " LDAP exists in /etc/hosts, removing..."
        echo "sudo sed -i '/ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts" >> hosts_additions.txt
        echo $host_ip"   ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ "$install_mode" =  "local" ]; then
        sudo chmod o+w /etc/hosts
        echo "172.16.8.11   ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
        sudo chmod o-w /etc/hosts
    fi
else
    if [ "$install_mode" = "vm" ]; then
        echo $host_ip"   ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ "$install_mode" = "local" ]; then
        sudo chmod o+w /etc/hosts
        echo "172.16.8.11   ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
        sudo chmod o-w /etc/hosts
    fi
fi
echo "****************************************************************************************************************"
echo " Creating LDAP secrets" 
echo "****************************************************************************************************************"
export LLDAP_JWT_SECRET=$(print_random)
export LLDAP_KEY_SEED=$(print_random)
echo "****************************************************************************************************************"
echo " Starting Ldap"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --remove-orphans ldap
echo " "
echo "****************************************************************************************************************"
echo " Adding users and groups to LDAP server" 
echo "****************************************************************************************************************"
docker compose exec ldap /bootstrap/bootstrap.sh
echo " "
