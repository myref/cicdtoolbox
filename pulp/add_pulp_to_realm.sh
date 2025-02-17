#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#Add Pulp
PULP_ID=$(./kcadm.sh create clients \
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
    -o --fields id | grep id | cut -d'"' -f 4)

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

toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Retrieved Toolbox Admins group ID: ${toolbox_admin_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Pulp \
    --rolename pulp-admin

echo "Added Pulp Admin role to Toolbox Admins group"
tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Designer Group ID: ${tool_dev_designer_id}" 

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

echo "Added Pulp roles to Tooling Designer group"
tool_ops_oper_id=$(cat TOOL_OPS_OPER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Operator group ID: ${tool_ops_oper_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Pulp \
    --rolename pulp-docker-pull \
    --rolename pulp-read \
    --rolename pulp-apt-ubuntu-read

echo "Added Pulp roles to Tooling Operator group"
tool_ops_spec_id=$(cat TOOL_OPS_SPEC | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Specialist group ID: ${tool_ops_spec_id}" 

./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Pulp \
    --rolename pulp-docker-pull \
    --rolename pulp-read \
    --rolename pulp-apt-ubuntu-read

echo "Added Pulp roles to Tooling Specialist group" 