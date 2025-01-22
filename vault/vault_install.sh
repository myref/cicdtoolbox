
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

function create_intermediate() {
    echo "****************************************************************************************************************"
    echo " Preparing ${1} intermediate CA in Vault" 
    echo "****************************************************************************************************************"
    vault secrets enable -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -path=pki_intermediate_$1 pki
    vault secrets tune -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -max-lease-ttl=43800h pki_intermediate_$1
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -format=json pki_intermediate_$1/intermediate/generate/internal common_name="${1}.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} Intermediate Authority" | jq -r '.data.csr' > ./vault/certs/pki_intermediate_$1.csr
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -format=json pki/root/sign-intermediate csr=@vault/certs/pki_intermediate_$1.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > ./vault/certs/pki_intermediate_$1.crt
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" pki_intermediate_$1/intermediate/set-signed certificate=@vault/certs/pki_intermediate_$1.crt
    echo "****************************************************************************************************************"
    echo " Define role to permit issueing leaf certificates" 
    echo "****************************************************************************************************************"
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" pki_intermediate_$1/roles/$1.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} allowed_domains="${1}.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" allow_subdomains=true max_ttl="8760h"
    echo " " 
}

function create_leaf() {
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -format=json pki_intermediate_$2/issue/$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} common_name="${1}.${2}.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" ttl="8760h" > ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.json
    cat ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.json | jq -r '.data.private_key' > ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem
    cat ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.json | jq -r '.data.certificate' > ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt
    cat ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.json | jq -r '.data.ca_chain[]' >> ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt
    rm ./vault/certs/$1.$2.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.json
    echo "Created leaf for ${1}.${2}.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}"
}

function create_database() {
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" database/config/$1 \
    plugin_name="postgresql-database-plugin" \
    allowed_roles=$1 \
    connection_url="postgresql://{{username}}:{{password}}@cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:5432/${1}" \
    username=$1 \
    password=$1

    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" database/roles/$1 \
    db_name=$1 \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

    vault write -force  -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" database/rotate-root/$1
}

function create_approle() {
    vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" auth/approle/role/$1 \
    token_type=batch \
    secret_id_ttl=10m \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40
    my_id=$(vault read -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" auth/approle/role/$1/role-id | grep role_id | cut -d " " -f 5)
    echo "$1 role_id = " $my_id
    echo $my_id > vault/ids/$1_vault_id.txt
}
echo "****************************************************************************************************************"
echo " Cleanup Consul and Vault"
echo "****************************************************************************************************************"
rm -f vault/conf/consul/consul-config.json
rm -f vault/conf/vault/vault-config-ssl.json
rm -f vault/conf/vault/vault-config.json
echo "****************************************************************************************************************"
echo " Ensure reachability of Consul through the hosts_additions.txt file"
echo "****************************************************************************************************************"
if grep -q "consul" /etc/hosts; then
    if [ $install_mode == "vm" ]; then
        echo " Consul exists in /etc/hosts, removing..."
        echo "sudo sed -i '/consul.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts" >> hosts_additions.txt
        echo $host_ip"   consul.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ $install_mode == "local" ]; then
        echo "172.16.9.4   consul.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    fi
else
    if [ $install_mode == "vm" ]; then
        echo $host_ip"   consul.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ $install_mode == "local" ]; then
        echo "172.16.9.4   consul.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    fi
fi
echo "****************************************************************************************************************"
echo " Ensure reachability of Vault through the hosts_additions.txt file"
echo "****************************************************************************************************************"
if grep -q "Vault" /etc/hosts; then
    if [ $install_mode == "vm" ]; then
        echo " Vault exists in /etc/hosts, removing..."
        echo "sudo sed -i '/vault.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts" >> hosts_additions.txt
        echo $host_ip"   vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ $install_mode == "local" ]; then
        echo "172.16.9.4   vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    fi
else
    if [ $install_mode == "vm" ]; then
        echo $host_ip"   vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    elif [ $install_mode == "local" ]; then
        echo "172.16.9.4   vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
    fi
fi
echo "****************************************************************************************************************"
echo " Cleaning Vault" 
echo "****************************************************************************************************************"
rm -f certs/*.json
rm -f certs/*.pem
rm -f certs/*.crt
rm -f certs/*.csr
rm -f *.txt
echo " " 
echo "****************************************************************************************************************"
echo " Configuring Consul backend" 
echo "****************************************************************************************************************"
cp conf/consul/consul-config.json.org conf/consul/consul-config.json
sed -i -e 's/${DOMAIN_NAME_SL}/\"${DOMAIN_NAME_SL}\"/' vault/conf/consul/consul-config.json
sed -i -e 's/${DOMAIN_NAME_TL}/\"${DOMAIN_NAME_TL}\"/' vault/conf/consul/consul-config.json
echo "****************************************************************************************************************"
echo " Configuring Vault backend" 
echo "****************************************************************************************************************"
cp conf/vault/vault-config.json.org conf/vault/vault-config-ssl.json
sed -i -e 's/${DOMAIN_NAME_SL}/\"${DOMAIN_NAME_SL}\"/' vault/conf/vault/vault-config-ssl.json
sed -i -e 's/${DOMAIN_NAME_TL}/\"${DOMAIN_NAME_TL}\"/' vault/conf/vault/vault-config.-ssljson
cp conf/vault/vault-config.json.org conf/vault/vault-config.json
sed -i -e 's/${DOMAIN_NAME_SL}/\"${DOMAIN_NAME_SL}\"/' vault/conf/vault/vault-config.json
sed -i -e 's/${DOMAIN_NAME_TL}/\"${DOMAIN_NAME_TL}\"/' vault/conf/vault/vault-config.json
echo "****************************************************************************************************************"
echo " Starting Vault and Consul backend" 
echo "****************************************************************************************************************"
docker compose up -d --build --remove-orphans consul
docker compose up -d --build --remove-orphans vault
echo "****************************************************************************************************************"
echo " Wait until vault is running (~5 sec.)"
echo "****************************************************************************************************************"
let t=0
until $(curl --output /dev/null --insecure --silent --head --fail http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200); do
    spin
done
endspin
echo " "
echo "****************************************************************************************************************"
echo " Initialize Vault, unseal and create secrets engines."
echo "****************************************************************************************************************"
robot -d ./install_log -o 00_vault.xml -l 00_vault_log.html -r 00_vault_report.html ./vault/vault-setup.robot
echo "****************************************************************************************************************"
echo " " 
echo "****************************************************************************************************************"
echo " We now have a Hashicorp Vault running with Consul. " 
echo "****************************************************************************************************************"
echo " " 
echo "****************************************************************************************************************"
echo " CLI Login to Vault" 
echo "****************************************************************************************************************"
export VAULT_TOKEN=$(cat vault/token.txt)
vault login -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" $(cat vault/token.txt)
echo "****************************************************************************************************************"
echo " Preparing Root CA in Vault" 
echo "****************************************************************************************************************"
vault secrets tune -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -max-lease-ttl=87600h pki
vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" -field=certificate pki/root/generate/internal common_name="${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" ttl=87600h > ./vault/certs/ca.crt
vault write -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" pki/config/urls issuing_certificates="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/v1/pki/ca" crl_distribution_points="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/v1/pki/crl"
echo " " 
echo "****************************************************************************************************************"
echo " Permitting this host to use the new CA" 
echo "****************************************************************************************************************"
echo " " 
sudo cp vault/certs/ca.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
echo " " 
echo "****************************************************************************************************************"
echo " Creating intermediates" 
echo "****************************************************************************************************************"
echo " " 
create_intermediate delivery
create_intermediate iam
create_intermediate internal
create_intermediate tooling
create_intermediate services
echo "****************************************************************************************************************"
echo " Intermediates defined" 
echo "****************************************************************************************************************"
echo " " 
echo "****************************************************************************************************************"
echo " Creating leaf certificates" 
echo "****************************************************************************************************************"
echo " " 
create_leaf cicdtoolbox-db internal 
create_leaf gitea tooling 
create_leaf jenkins tooling 
create_leaf build-dev delivery  
create_leaf build-test delivery  
create_leaf build-acc delivery  
create_leaf build-prod delivery  
create_leaf keycloak services 
create_leaf ldap iam  
create_leaf pulp tooling 
create_leaf vault internal 
echo " " 
echo "****************************************************************************************************************"
echo " Creating AppRoles" 
echo "****************************************************************************************************************"
echo " " 
vault auth enable -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" approle
create_approle git-jenkins
create_approle jenkins-git
create_approle jenkins-jenkins
create_approle jenkins-nexus
create_approle jenkins-ansible
echo "****************************************************************************************************************"
echo " Preparing PostgreSQL database use" 
echo "****************************************************************************************************************"
echo " " 
vault secrets enable -address="http://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" database
echo " " 
echo "****************************************************************************************************************"
echo " Now give Vault it's certificates" 
echo "****************************************************************************************************************"
echo " " 
docker cp vault/certs/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt
docker cp vault/certs/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem
docker cp vault/certs/ca.crt vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/vault/config/ca.crt
echo " " 
echo "****************************************************************************************************************"
echo " Make sure the owner is correct and it has the correct permissions" 
echo "****************************************************************************************************************"
echo " " 
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chown root:root /vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt"
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chmod 644 /vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt"
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chown root:root /vault/config/ca.crt"
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chmod 644 /vault/config/ca.crt"
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chown root:root /vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem"
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chmod 600 /vault/config/vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem"
echo " " 
echo "****************************************************************************************************************"
echo " Copy SSL config to vault" 
echo "****************************************************************************************************************"
echo " " 
docker cp vault/conf/vault/vault-config-ssl.json vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/vault/config/vault-config.json
docker exec -it vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "chmod 644 /vault/config/vault-config.json"
echo " " 
echo "****************************************************************************************************************"
echo " Restarting vault" 
echo "****************************************************************************************************************"
echo " " 
docker restart vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
echo "****************************************************************************************************************"
echo " Wait until Vault is running (~10 sec.)"
echo "****************************************************************************************************************"
let t=0
until $(curl --output /dev/null --silent --head --fail https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200); do
    spin
done
endspin
echo " " 
echo "****************************************************************************************************************"
echo " Unsealing vault" 
echo "****************************************************************************************************************"
echo " " 
echo pwd
echo " "
vault operator unseal -address="https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" $(cat ./vault/key.txt)
echo " " 
echo "****************************************************************************************************************"
echo " Saving CA self-signed certificate"
echo "****************************************************************************************************************"
cp vault/certs/ca.crt cicdtoolbox-db/ca.crt
cp vault/certs/ca.crt gitea/ca.crt
cp vault/certs/ca.crt jenkins/ca.crt
cp vault/certs/ca.crt jenkins_buildnode/ca.crt
cp vault/certs/ca.crt keycloak/ca.crt
cp vault/certs/ca.crt pulp/ca.crt
echo "****************************************************************************************************************"
echo " Saving database certificates"
echo "****************************************************************************************************************"
cp vault/certs/cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem cicdtoolbox-db/docker-entrypoint-initdb-resources/server.key
cp vault/certs/cicdtoolbox-db.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt cicdtoolbox-db/docker-entrypoint-initdb-resources/server.crt
cp vault/certs/ca.crt cicdtoolbox-db/docker-entrypoint-initdb-resources/root.crt
echo " "
