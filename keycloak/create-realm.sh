#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $4 --password $1
echo "Credentials created"

#add realm
./kcadm.sh create realms \
    -s realm=cicdtoolbox \
    -s id=cicdtoolbox \
    -s enabled=true \
    -s displayName="Welcome to your Development Toolkit" \
    -s displayNameHtml="<b>Welcome to your Development Toolkit</b>"
echo "Realm created"

#add Hashicorp Vault client
./kcadm.sh create clients \
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
    -o --fields id >cicdtoolbox_VAULT

# output is Created new client with id, we now need to grep the ID out of it
VAULT_ID=$(cat cicdtoolbox_VAULT | grep id | cut -d'"' -f 4)
echo "Created Vault client with ID: ${VAULT_ID}" 

# Create Client secret
./kcadm.sh create clients/$VAULT_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$VAULT_ID/client-secret -r cicdtoolbox >cicdtoolbox_vault_secret
VAULT_token=$(grep value cicdtoolbox_vault_secret | cut -d '"' -f4)
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

#add Gitea client
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Gitea" \
    -s description="The Gitea git server in the toolchain" \
    -s clientId=Gitea \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000 \
    -s adminUrl=https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/ \
    -s "redirectUris=[\"https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/user/oauth2/keycloak/callback\"]" \
    -s "webOrigins=[\"https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/\"]" \
    -o --fields id >cicdtoolbox_GITEA

# output is Created new client with id, we now need to grep the ID out of it
GITEA_ID=$(cat cicdtoolbox_GITEA | grep id | cut -d'"' -f 4)
echo "Created Gitea client with ID: ${GITEA_ID}" 

# Create Client secret
./kcadm.sh create clients/$GITEA_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$GITEA_ID/client-secret -r cicdtoolbox >cicdtoolbox_gitea_secret
GITEA_token=$(grep value cicdtoolbox_gitea_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source in Gitea for Keycloak
echo "GITEA_token: ${GITEA_token}"

# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name=giteaAdmin -s description='The admin role for the Infra Automators organization'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name=$ORG_NAME -s description="Organization owner role in the ${ORG_NAME} organization"
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-cicdtoolbox-read' -s description='A read-only role on the CICD toolbox'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-cicdtoolbox-write' -s description='A read-write role on the CICD toolbox'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-cicdtoolbox-admin' -s description='A read-write role on the CICD toolbox'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-netcicd-read' -s description='A read-only role on NetCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-netcicd-write' -s description='A read-write role on NetCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-netcicd-admin' -s description='A admin role on NetCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-appcicd-read' -s description='A read-only role on AppCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-appcicd-write' -s description='A read-write role on AppCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-appcicd-admin' -s description='A admin role on AppCICD'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-templateapp-read' -s description='A read-only role on templateApp'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-templateapp-write' -s description='A read-write role on templateApp'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-templateapp-admin' -s description='A admin role on templateApp'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-oscicd-read' -s description='A read-only role on the myapp OS deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-oscicd-write' -s description='A read-write role on myapp OS deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-oscicd-admin' -s description='A admin role on myapp OS deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-osdeploy-read' -s description='A read-only role on the myapp radar deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-osdeploy-write' -s description='A read-write role on myapp radar deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-osdeploy-admin' -s description='A admin role on myapp radar deployment repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-ostest-read' -s description='A read-only role on the myapp radar test repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-ostest-write' -s description='A read-write role on myapp radar test repository'
./kcadm.sh create clients/$GITEA_ID/roles -r cicdtoolbox -s name='gitea-ostest-admin' -s description='A admin role on myapp radar test repository'

# We need to add the gitea-admin claim and gitea-group claim to the token
./kcadm.sh create clients/$GITEA_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=group-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-usermodel-client-role-mapper \
    -s consentRequired=false \
	-s config="{\"multivalued\" : \"true\",\"userinfo.token.claim\" : \"true\",\"id.token.claim\" : \"true\",\"access.token.claim\" : \"true\",\"claim.name\" : \"giteaGroups\",\"jsonType.label\" : \"String\",\"usermodel.clientRoleMapping.clientId\" : \"Gitea\"}"

echo "Created role-group mapper in the Client Scope" 

#Add Jenkins client
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Jenkins" \
    -s description="The Jenkins orchestrator in the toolchain" \
    -s clientId=Jenkins \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=true \
    -s authorizationServicesEnabled=true \
    -s rootUrl=https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084 \
    -s adminUrl=https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/ \
    -s "redirectUris=[ \"https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/*\" ]" \
    -s "webOrigins=[\"https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/\" ]" \
    -o --fields id >cicdtoolbox_JENKINS

# output is Created new client with id, we now need to grep the ID out of it
JENKINS_ID=$(cat cicdtoolbox_JENKINS | grep id | cut -d'"' -f 4)
echo "Created Jenkins client with ID: ${JENKINS_ID}" 

# Create Client secret
./kcadm.sh create clients/$JENKINS_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$JENKINS_ID/client-secret -r cicdtoolbox >cicdtoolbox_jenkins_secret
JENKINS_token=$(grep value cicdtoolbox_jenkins_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source in Gitea for Keycloak
echo "JENKINS_token: ${JENKINS_token}"


# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-admin -s description='The admin role for Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-user -s description='A user in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-readonly -s description='A viewer in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-git -s description='A role for Jenkins to work with Git'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-cicdtoolbox-run -s description='The role to be used for a user that needs to run the NetCICD-developer-toolbox pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-cicdtoolbox-dev -s description='The role to be used for a user that needs to configure the NetCICD-developer-toolbox pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-netcicd-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-netcicd-run -s description='The role to be used for a user that needs to run the NetCICD pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-netcicd-dev -s description='The role to be used for a user that needs to configure the NetCICD pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-appcicd-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-appcicd-run -s description='The role to be used for a user that needs to run the AppCICD pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-appcicd-dev -s description='The role to be used for a user that needs to configure the AppCICD pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-templateapp-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-templateapp-run -s description='The role to be used for a user that needs to run the templateapp pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-templateapp-dev -s description='The role to be used for a user that needs to configure the templateapp pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-oscicd-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-oscicd-run -s description='The role to be used for a user that needs to run the myapp OS development pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-oscicd-dev -s description='The role to be used for a user that needs to configure the myapp OS development pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-osdeploy-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-osdeploy-run -s description='The role to be used for a user that needs to run the myapp radar development pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-osdeploy-dev -s description='The role to be used for a user that needs to configure the myapp radar development pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-ostest-agent -s description='The role to be used for a user that needs to create agents in Jenkins'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-ostest-run -s description='The role to be used for a user that needs to run the myapp radar test pipeline'
./kcadm.sh create clients/$JENKINS_ID/roles -r cicdtoolbox -s name=jenkins-ostest-dev -s description='The role to be used for a user that needs to configure the myapp radar test pipeline'

echo "Created Jenkins roles." 

# Now we need a service account for other systems to log into Jenkins
./kcadm.sh add-roles -r cicdtoolbox \
    --uusername service-account-jenkins \
    --cclientid realm-management \
    --rolename view-clients \
    --rolename view-realm \
    --rolename view-users \
    --rolename gitea-oscicd-read \
    --rolename gitea-oscicd-write \
    --rolename gitea-osdeploy-read \
    --rolename gitea-osdeploy-write &>cicdtoolbox_JENKINS_SCOPE

echo "Created Jenkins Service Account" 

# We need to add a client scope on the realm for Jenkins in order to include the audience in the access token
./kcadm.sh create -x "client-scopes" -r cicdtoolbox -s name=jenkins-audience -s protocol=openid-connect &>cicdtoolbox_JENKINS_SCOPE
JENKINS_SCOPE_ID=$(cat cicdtoolbox_JENKINS_SCOPE | grep id | cut -d"'" -f 2)
echo "Created Client scope for Jenkins with id: ${JENKINS_SCOPE_ID}" 

# Create a mapper for the audience
./kcadm.sh create clients/$JENKINS_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=jenkins-audience-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-audience-mapper \
    -s consentRequired=false \
	-s config="{\"included.client.audience\" : \"Jenkins\",\"id.token.claim\" : \"false\",\"access.token.claim\" : \"true\"}"

echo "Created audience mapper in the Client Scope" 

# We need to add the scope to the token
./kcadm.sh update clients/$JENKINS_ID/default-client-scopes/${JENKINS_SCOPE_ID} -r cicdtoolbox 

echo "Included Jenkins Audience in token" 

./kcadm.sh create clients/$JENKINS_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=role-group-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-usermodel-client-role-mapper \
    -s consentRequired=false \
	-s config="{\"multivalued\" : \"true\",\"userinfo.token.claim\" : \"true\",\"id.token.claim\" : \"false\",\"access.token.claim\" : \"false\",\"claim.name\" : \"groupmembership\",\"jsonType.label\" : \"String\",\"usermodel.clientRoleMapping.clientId\" : \"Jenkins\"}"

echo "Created role-group mapper in the Client Scope for Jenkins" 
echo "Jenkins configuration finished"
echo ""

#Add Pulp
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Pulp" \
    -s description="The Pulp repository in the toolchain" \
    -s clientId=Pulp \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=true \
    -s authorizationServicesEnabled=true \
    -s rootUrl=https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 \
    -s adminUrl=https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/ \
    -s "redirectUris=[\"https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/*\" ]" \
    -s "webOrigins=[\"https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/\" ]" \
    -o --fields id >cicdtoolbox_PULP

# output is Created new client with id, we now need to grep the ID out of it
PULP_ID=$(cat cicdtoolbox_PULP | grep id | cut -d'"' -f 4)
echo "Created Pulp client with ID: ${PULP_ID}" 

# Create Client secret
./kcadm.sh create clients/$PULP_ID/client-secret -r cicdtoolbox

# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-admin -s description='The admin role for Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-read -s description='The role to be used to read data on Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-docker-pull -s description='The role to be used in order to pull from the Docker mirror on Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-docker-push -s description='The role to be used in order to push to the Docker mirror on Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-apk-read -s description='The role to be used for a NetCICD client to pull  APK packages data from Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-apt-ubuntu-read -s description='The role to be used for a NetCICD client to pull Ubuntu based apt packages data from Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-cicdtoolbox-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-netcicd-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-appcicd-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-templateapp-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-oscicd-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-osdeploy-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'
./kcadm.sh create clients/$PULP_ID/roles -r cicdtoolbox -s name=pulp-ostest-agent -s description='The role to be used for a Jenkins agent to push data to Pulp'

echo "Created Pulp roles." 

# Now add the scope mappings for Pulp
RM_ID=$(./kcadm.sh get -r cicdtoolbox clients | grep realm-management -B1 | grep id | cut -d ":" -f 2 | cut -d '"' -f2)

./kcadm.sh create -r cicdtoolbox clients/$PULP_ID/scope-mappings/clients/$RM_ID  --body "[{\"name\": \"view-realm\"}]"
./kcadm.sh create -r cicdtoolbox clients/$PULP_ID/scope-mappings/clients/$RM_ID  --body "[{\"name\": \"view-users\"}]"
./kcadm.sh create -r cicdtoolbox clients/$PULP_ID/scope-mappings/clients/$RM_ID  --body "[{\"name\": \"view-clients\"}]"
echo "Created Pulp Scope mappings" 

# Service account
./kcadm.sh add-roles -r cicdtoolbox --uusername service-account-pulp --cclientid account --rolename manage-account --rolename manage-account-links --rolename view-profile
./kcadm.sh add-roles -r cicdtoolbox --uusername service-account-pulp --cclientid Pulp --rolename uma_protection --rolename pulp-admin
./kcadm.sh add-roles -r cicdtoolbox --uusername service-account-pulp --cclientid realm-management --rolename view-clients --rolename view-realm --rolename view-users

echo "Created Pulp Service Account" 

#download Pulp OIDC file
./kcadm.sh get clients/$PULP_ID/installation/providers/keycloak-oidc-keycloak-json -r cicdtoolbox > keycloak-pulp.json

echo "Created keycloak-pulp installation json" 
echo "Pulp configuration finished"
echo ""

#Add Build_dev node
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="build_dev" \
    -s description="First step build node for Jenkins for Development jobs" \
    -s clientId=build_dev \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://build_dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} \
    -s adminUrl=https://build_dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/ \
    -s "redirectUris=[\"https://build_dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/user/oauth2/keycloak/callback\" ]" \
    -s "webOrigins=[\"https://build_dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/\" ]" \
    -o --fields id >cicdtoolbox_build_dev

# output is Created new client with id, we now need to grep the ID out of it
BUILD_DEV_ID=$(cat cicdtoolbox_build_dev | grep id | cut -d'"' -f 4)
echo "Created cicdtoolbox_build_dev client with ID: ${BUILD_DEV_ID}" 

# Create Client secret
./kcadm.sh create clients/$BUILD_DEV_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$BUILD_DEV_ID/client-secret -r cicdtoolbox >cicdtoolbox_build_dev_secret
BUILD_DEV_token=$(grep value cicdtoolbox_build_dev_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source for Keycloak
echo "Build_dev_token: ${BUILD_DEV_token}"
echo "Build_dev configuration finished"
echo ""

#Add Build_test node
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="build_test" \
    -s description="First step build node for Jenkins for Test jobs" \
    -s clientId=build_test \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://build_test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} \
    -s adminUrl=https://build_test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/ \
    -s "redirectUris=[\"https://build_test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/user/oauth2/keycloak/callback\" ]" \
    -s "webOrigins=[\"https://build_test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/\" ]" \
    -o --fields id >cicdtoolbox_build_test

# output is Created new client with id, we now need to grep the ID out of it
BUILD_TEST_ID=$(cat cicdtoolbox_build_test | grep id | cut -d'"' -f 4)
echo "Created cicdtoolbox_build_test client with ID: ${BUILD_TEST_ID}" 

# Create Client secret
./kcadm.sh create clients/$BUILD_TEST_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$BUILD_TEST_ID/client-secret -r cicdtoolbox >cicdtoolbox_build_test_secret
BUILD_TEST_token=$(grep value cicdtoolbox_build_test_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source for Keycloak
echo "Build_test_token: ${BUILD_TEST_token}"
echo "Build_test configuration finished"
echo ""

#Add Build_acc node
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="build_acc" \
    -s description="First step build node for Jenkins for Acceptance jobs" \
    -s clientId=build_acc \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://build_acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} \
    -s adminUrl=https://build_acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/ \
    -s "redirectUris=[\"https://build_acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/user/oauth2/keycloak/callback\" ]" \
    -s "webOrigins=[\"https://build_acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/\" ]" \
    -o --fields id >cicdtoolbox_build_acc

# output is Created new client with id, we now need to grep the ID out of it
BUILD_ACC_ID=$(cat cicdtoolbox_build_acc | grep id | cut -d'"' -f 4)
echo "Created cicdtoolbox_build_acc client with ID: ${BUILD_ACC_ID}" 

# Create Client secret
./kcadm.sh create clients/$BUILD_ACC_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$BUILD_ACC_ID/client-secret -r cicdtoolbox >cicdtoolbox_build_acc_secret
BUILD_ACC_token=$(grep value cicdtoolbox_build_acc_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source for Keycloak
echo "Build_acc_token: ${BUILD_ACC_token}"

#Add Build_prod node
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="build_prod" \
    -s description="First step build node for Jenkins for Production jobs" \
    -s clientId=build_prod \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://build_prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} \
    -s adminUrl=https://build_prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/ \
    -s "redirectUris=[\"https://build_prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/user/oauth2/keycloak/callback\" ]" \
    -s "webOrigins=[\"https://build_prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/\" ]" \
    -o --fields id >cicdtoolbox_build_prod

# output is Created new client with id, we now need to grep the ID out of it
BUILD_PROD_ID=$(cat cicdtoolbox_build_prod | grep id | cut -d'"' -f 4)
echo "Created cicdtoolbox_build_prod client with ID: ${BUILD_PROD_ID}" 

# Create Client secret
./kcadm.sh create clients/$BUILD_PROD_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$BUILD_PROD_ID/client-secret -r cicdtoolbox >cicdtoolbox_build_prod_secret
BUILD_PROD_token=$(grep value cicdtoolbox_build_prod_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source for Keycloak
echo "Build_prod_token: ${BUILD_PROD_token}"
echo "Build_prod configuration finished"
echo ""

./kcadm.sh create groups -r cicdtoolbox -s name="cicd_agents" &>cicd_AGENTS
cicd_agents_id=$(cat cicd_AGENTS | grep id | cut -d"'" -f 2)
echo "Created cicdtoolbox Agents with ID: ${cicd_agents_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $cicd_agents_id \
    --cclientid Jenkins \
    --rolename jenkins-netcicd-agent \
    --rolename jenkins-appcicd-agent \
    --rolename jenkins-templateapp-agent \
    --rolename jenkins-oscicd-agent \
    --rolename jenkins-ostest-agent \
    --rolename jenkins-osdeploy-agent

./kcadm.sh create groups -r cicdtoolbox -s name="git_from_jenkins" &>cicdtoolbox_J_G
j_g_id=$(cat cicdtoolbox_J_G | grep id | cut -d"'" -f 2)
echo "Created git_from_jenkins group with ID: ${j_g_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $j_g_id \
    --cclientid Jenkins \
    --rolename jenkins-git 

./kcadm.sh create groups -r cicdtoolbox -s name="toolbox_admin" &>TOOLBOX_ADMIN
toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Created Toolbox Admins group with ID: ${toolbox_admin_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Gitea \
    --rolename $ORG_NAME \
    --rolename giteaAdmin 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Jenkins \
    --rolename jenkins-admin 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Pulp \
    --rolename pulp-admin

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Vault \
    --rolename vault-admin

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_dev_design" &>TOOL_DEV_DESIGNER
tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)

echo "Created Tooling Designer Group with ID: ${tool_dev_designer_id}" 

#adding client roles to the group
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

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_dev_designer_id \
    --cclientid Gitea \
    --rolename gitea-appcicd-admin \
    --rolename gitea-templateapp-admin \
    --rolename gitea-cicdtoolbox-admin \
    --rolename gitea-oscicd-admin \
    --rolename gitea-ostest-admin \
    --rolename gitea-osdeploy-admin \
    --rolename gitea-netcicd-admin 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_dev_designer_id \
    --cclientid Jenkins \
    --rolename jenkins-user \
    --rolename jenkins-appcicd-dev \
    --rolename jenkins-templateapp-dev \
    --rolename jenkins-cicdtoolbox-dev \
    --rolename jenkins-oscicd-dev \
    --rolename jenkins-ostest-dev \
    --rolename jenkins-osdeploy-dev \
    --rolename jenkins-netcicd-dev    

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_dev_designer_id \
    --cclientid Pulp \
    --rolename pulp-docker-pull \
    --rolename pulp-read \
    --rolename pulp-apt-ubuntu-read \
    --rolename pulp-cicdtoolbox-agent \
    --rolename pulp-appcicd-agent \
    --rolename pulp-netcicd-agent \
    --rolename pulp-oscicd-agent \
    --rolename pulp-osdeploy-agent \
    --rolename pulp-ostest-agent \
    --rolename pulp-templateapp-agent

echo "Added roles to Tooling Designer."

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_ops_oper" &>TOOL_OPS_OPER
tool_ops_oper_id=$(cat TOOL_OPS_OPER | grep id | cut -d"'" -f 2)
echo "Created Tooling Operator group within the Tooling Operations Department with ID: ${tool_ops_oper_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Gitea \
    --rolename gitea-oscicd-read \
    --rolename gitea-ostest-read \
    --rolename gitea-osdeploy-read

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Jenkins \
    --rolename jenkins-user \
    --rolename jenkins-oscicd-run \
    --rolename jenkins-ostest-run \
    --rolename jenkins-osdeploy-run

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Pulp \
    --rolename pulp-docker-pull \
    --rolename pulp-read \
    --rolename pulp-apt-ubuntu-read

echo "Added roles to Tooling Operator."

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_ops_spec" &>TOOL_OPS_SPEC
tool_ops_spec_id=$(cat TOOL_OPS_SPEC | grep id | cut -d"'" -f 2)
echo "Created Tooling Specialist group within the Tooling Operations Department with ID: ${tool_ops_spec_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Gitea \
    --rolename gitea-oscicd-read \
    --rolename gitea-ostest-read \
    --rolename gitea-osdeploy-read

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Jenkins \
    --rolename jenkins-user \
    --rolename jenkins-oscicd-run \
    --rolename jenkins-ostest-run \
    --rolename jenkins-osdeploy-run

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Pulp \
    --rolename pulp-docker-pull \
    --rolename pulp-read \
    --rolename pulp-apt-ubuntu-read

echo "Added roles to Tooling Specialist."

# Add LLDAP integration, needs to be last, otherwise LLDAP groups interfere with group creation in Keycloak
./kcadm.sh create components -r cicdtoolbox \
    -s name=lldap \
    -s providerId=ldap \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s 'config.priority=["2"]' \
    -s 'config.editMode=["READ_ONLY"]' \
    -s 'config.syncRegistrations=["true"]' \
    -s 'config.vendor=["other"]' \
    -s 'config.usernameLDAPAttribute=["uid"]' \
    -s 'config.rdnLDAPAttribute=["uid"]' \
    -s 'config.uuidLDAPAttribute=["uid"]' \
    -s 'config.userObjectClasses=["person"]' \
    -s "config.connectionUrl=[\"ldap://ldap.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3890\"]" \
    -s "config.usersDn=[\"ou=people,dc=${DOMAIN_NAME_SL},dc=${DOMAIN_NAME_TL}\"]" \
    -s 'config.searchScope=["1"]' \
    -s 'config.authType=["simple"]' \
    -s "config.bindDn=[\"uid=admin,ou=people,dc=${DOMAIN_NAME_SL},dc=${DOMAIN_NAME_TL}\"]" \
    -s 'config.bindCredential=["'$3'"]' \
    -s 'config.useTruststoreSpi=["ldapsOnly"]' \
    -s 'config.pagination=["false"]' \
    -s 'config.connectionPooling=["true"]' \
    -s 'config.useKerberosForPasswordAuthentication=["false"]' \
    -s 'config.batchSizeForSync=["1000"]' \
    -s 'config.fullSyncPeriod=["10"]' &>LLDAP_LDAP

lldap_ldap_id=$(cat LLDAP_LDAP | grep id | cut -d"'" -f 2)

./kcadm.sh create components -r cicdtoolbox \
    -s name=groups \
    -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
    -s parentId=${lldap_ldap_id} \
    -s "config.\"groups.dn\"=[\"ou=groups,dc=${DOMAIN_NAME_SL},dc=${DOMAIN_NAME_TL}\"]" \
    -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["groupOfUniqueNames"]' \
    -s 'config.mode=["READ_ONLY"]'

echo "LLDAP configured"
#Now delete tokens and secrets
rm cicdtoolbox_*
