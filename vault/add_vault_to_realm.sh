#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#add Hashicorp Vault client
VAULT_ID=$(./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Vault" \
    -s description="The Vault secrets store and PKI for the toolchain" \
    -s clientId=Vault \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200 \
    -s adminUrl=https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/ \
    -s "redirectUris=[ \"https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/oidc/oidc/callback\",\"https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/ui/vault/auth/oidc/oidc/callback\" ]" \
    -s "webOrigins=[ \"https://vault.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8200/\" ]" \
    -o --fields id | grep id | cut -d'"' -f 4)

echo "Created Vault client with ID: ${VAULT_ID}" 

# Create Client secret
./kcadm.sh create clients/$VAULT_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$VAULT_ID/client-secret -r cicdtoolbox >cicdtoolbox_vault_secret
VAULT_token=$(grep value cicdtoolbox_vault_secret | cut -d '"' -f4)
echo $test
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source in Vault for Keycloak
echo "VAULT_token: ${VAULT_token}"

# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-admin' -s description='The admin role for the Infra Automators organization'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name=$ORG_NAME -s description="Organization owner role in the ${ORG_NAME} organization"
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-cicdtoolbox-read' -s description='A read-only role on the CICD toolbox'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-cicdtoolbox-write' -s description='A read-write role on the CICD toolbox'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-cicdtoolbox-admin' -s description='A read-write role on the CICD toolbox'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-netcicd-read' -s description='A read-only role on NetCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-netcicd-write' -s description='A read-write role on NetCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-netcicd-admin' -s description='A admin role on NetCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-appcicd-read' -s description='A read-only role on AppCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-appcicd-write' -s description='A read-write role on AppCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-appcicd-admin' -s description='A admin role on AppCICD'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-templateapp-read' -s description='A read-only role on templateApp'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-templateapp-write' -s description='A read-write role on templateApp'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-templateapp-admin' -s description='A admin role on templateApp'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-oscicd-read' -s description='A read-only role on oscicd'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-oscicd-write' -s description='A read-write role on oscicd'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-oscicd-admin' -s description='A admin role on oscicd'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-osdeploy-read' -s description='A read-only role on osdeploy'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-osdeploy-write' -s description='A read-write role on osdeploy'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-osdeploy-admin' -s description='A admin role on osdeploy'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-ostest-read' -s description='A read-only role on ostest'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-ostest-write' -s description='A read-write role on ostest'
./kcadm.sh create clients/$VAULT_ID/roles -r cicdtoolbox -s name='vault-ostest-admin' -s description='A admin role on ostest'

# We need to add the vault-admin claim and vault-group claim to the token
./kcadm.sh create clients/$VAULT_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=group-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-usermodel-client-role-mapper \
    -s consentRequired=false \
	-s config="{\"multivalued\" : \"true\",\"userinfo.token.claim\" : \"true\",\"id.token.claim\" : \"true\",\"access.token.claim\" : \"true\",\"claim.name\" : \"vaultGroups\",\"jsonType.label\" : \"String\",\"usermodel.clientRoleMapping.clientId\" : \"Vault\"}"

echo "Created role-group mapper in the Client Scope" 

# # We need to add a client scope on the realm for Vault in order to include the audience in the access token
# ./kcadm.sh create -x "client-scopes" -r cicdtoolbox -s name=vault-audience -s protocol=openid-connect &>cicdtoolbox_VAULT_SCOPE
# VAULT_SCOPE_ID=$(cat cicdtoolbox_VAULT_SCOPE | grep id | cut -d"'" -f 2)
# echo "Created Client scope for Vault with id: ${VAULT_SCOPE_ID}" 

# Create a mapper for the audience
./kcadm.sh create clients/$VAULT_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=vault-audience-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-audience-mapper \
    -s consentRequired=false \
	-s config="{\"included.client.audience\" : \"https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/realms/cicdtoolbox\",\"id.token.claim\" : \"false\",\"access.token.claim\" : \"true\"}"

# echo "Created audience mapper in the Client Scope" 

#download Vault OIDC file
./kcadm.sh get clients/$VAULT_ID/installation/providers/keycloak-oidc-keycloak-json -r cicdtoolbox > keycloak-vault.json

echo "Created keycloak-vault installation json" 

toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Retrieved Toolbox Admins group ID: ${toolbox_admin_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Vault \
    --rolename vault-admin

tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Designer Group ID: ${tool_dev_designer_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_dev_designer_id \
    --cclientid Vault \
    --rolename vault-appcicd-admin \
    --rolename vault-templateapp-admin \
    --rolename vault-cicdtoolbox-admin \
    --rolename vault-oscicd-admin \
    --rolename vault-ostest-admin \
    --rolename vault-osdeploy-admin \
    --rolename vault-netcicd-admin 

