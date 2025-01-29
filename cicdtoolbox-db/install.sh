#!/bin/bash
echo "****************************************************************************************************************"
echo " Cleaning database" 
echo "****************************************************************************************************************"
rm -f cicdtoolbox-db/docker-entrypoint-initdb-resources/*
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of CICDtoolbox-db"
echo "****************************************************************************************************************"
if grep -q "cicdtoolbox-db" /etc/hosts; then
    if [ "$install_mode" = "vm" ]; then
        echo " CICDtoolbox-db exists in /etc/hosts, removing..."
        echo "sudo sed -i '/cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts" >> hosts_additions.txt
        echo $host_ip"   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ "$install_mode" =  "local" ]; then
        sudo chmod o+w /etc/hosts
        echo "172.16.9.2   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
        sudo chmod o-w /etc/hosts
    fi
else
    if [ "$install_mode" = "vm" ]; then
        echo $host_ip"   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ "$install_mode" = "local" ]; then
        sudo chmod o+w /etc/hosts
        echo "172.16.9.2   cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
        sudo chmod o-w /etc/hosts
    fi
fi
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