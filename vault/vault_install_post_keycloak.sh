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
echo " CLI Login to Vault" 
echo "****************************************************************************************************************"
vault login -address="https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200" $(cat vault/token.txt)
echo "****************************************************************************************************************"
echo " Setting up OIDC login" 
echo "****************************************************************************************************************"
echo " " 
echo "****************************************************************************************************************"
echo " Loading OIDC Vault-admin policy" 
echo "****************************************************************************************************************"
echo " " 
export VAULT_ADDR=https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200
export VAULT_TOKEN=$(cat vault/token.txt)
export TF_VAR_client_secret=$(grep VAULT_token install_log/keycloak_create.log | cut -d' ' -f2 | tr -d '\r' )
export TF_VAR_client_id="Vault"
echo "****************************************************************************************************************"
echo " Creating admin policy file with correct domain name" 
echo "****************************************************************************************************************"
rm terraform/vault/variables.tf
cp terraform/vault/variables.tf.org terraform/vault/variables.tf
sed -i "s/\${DOMAIN_NAME_TL}/${DOMAIN_NAME_TL}/" terraform/vault/variables.tf
sed -i "s/\${DOMAIN_NAME_SL}/${DOMAIN_NAME_SL}/" terraform/vault/variables.tf

terraform -chdir=terraform/vault init -input=false -e DOMAIN_NAME_SL=${DOMAIN_NAME_SL} -e DOMAIN_NAME_TL=${DOMAIN_NAME_TL}
terraform -chdir=terraform/vault apply --auto-approve
