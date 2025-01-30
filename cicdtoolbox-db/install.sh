#!/bin/bash
echo "****************************************************************************************************************"
echo " Cleaning database" 
echo "****************************************************************************************************************"
rm -f cicdtoolbox-db/docker-entrypoint-initdb-resources/*
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of CICDtoolbox-db"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "cicdtoolbox-db" /etc/hosts; then
    sudo sed -i "/cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.9.2   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Saving database certificates"
echo "****************************************************************************************************************"
cp vault/certs/cicdtoolbox-db.internal.*.pem cicdtoolbox-db/docker-entrypoint-initdb-resources/server.key
cp vault/certs/cicdtoolbox-db.internal.*.crt cicdtoolbox-db/docker-entrypoint-initdb-resources/server.crt
cp vault/certs/ca.crt cicdtoolbox-db/docker-entrypoint-initdb-resources/root.crt
echo " "
echo "****************************************************************************************************************"
echo " Starting CICDtoolbox-db"
echo "****************************************************************************************************************"
DOCKER_BUILDKIT=1 docker compose --project-name cicd-toolbox up -d --build cicdtoolbox-db
sleep 10