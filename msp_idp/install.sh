#!/bin/bash

print_random () {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32
}
echo "****************************************************************************************************************"
echo " Cleaning MSP-IDP" 
echo "****************************************************************************************************************"
rm -f msp_idp/data/*.crt
rm -rf msp_idp/data/*.pem
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of MSP-IDP"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "msp-idp" /etc/hosts; then
    sudo sed -i "/msp-idp.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.8.11   msp-idp.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   msp-idp.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Creating MSP-IDP secrets" 
echo "****************************************************************************************************************"
export MSP_IDP_JWT_SECRET=$(print_random)
export MSP_IDP_KEY_SEED=$(print_random)
echo "****************************************************************************************************************"
echo " Starting MSP_IDP"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --remove-orphans msp_idp
echo " "
echo "****************************************************************************************************************"
echo " Adding users and groups to MSP-IDP server" 
echo "****************************************************************************************************************"
docker compose exec msp_idp /bootstrap/bootstrap.sh
echo " "
