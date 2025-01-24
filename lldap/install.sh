#!/bin/bash

print_random () {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32
}

echo "****************************************************************************************************************"
echo " Creating LDAP secrets" 
echo "****************************************************************************************************************"
export LLDAP_JWT_SECRET=$(print_random)
export LLDAP_KEY_SEED=$(print_random)
echo "****************************************************************************************************************"
echo " Creating LDAP server" 
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --remove-orphans ldap
echo " "

