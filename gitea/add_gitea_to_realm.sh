#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#add Gitea client
GITEA_ID=$(./kcadm.sh create clients \
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
    -o --fields id | grep id | cut -d'"' -f 4)

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

toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Retrieved Toolbox Admins group ID: ${toolbox_admin_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Gitea \
    --rolename $ORG_NAME \
    --rolename giteaAdmin 

echo "Added Gitea Admin role to Toolbox Admins group"
tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Designer Group ID: ${tool_dev_designer_id}" 

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

echo "Added Gitea roles to Tooling Designer group"
tool_ops_oper_id=$(cat TOOL_OPS_OPER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Operator group ID: ${tool_ops_oper_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Gitea \
    --rolename gitea-oscicd-read \
    --rolename gitea-ostest-read \
    --rolename gitea-osdeploy-read

echo "Added Gitea roles to Tooling Operator group"
tool_ops_spec_id=$(cat TOOL_OPS_SPEC | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Specialist group ID: ${tool_ops_spec_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Gitea \
    --rolename gitea-oscicd-read \
    --rolename gitea-ostest-read \
    --rolename gitea-osdeploy-read

echo "Added Gitea roles to Tooling Specialist group" 