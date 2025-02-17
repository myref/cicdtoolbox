#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#Add Jenkins client
JENKINS_ID=$(./kcadm.sh create clients \
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
    -o --fields id | grep id | cut -d'"' -f 4)

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

cicd_agents_id=$(cat cicd_AGENTS | grep id | cut -d"'" -f 2)
echo "Retrieved cicdtoolbox Agents ID: ${cicd_agents_id}" 

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

echo "Added roles to cicdtoolbox Agents."
j_g_id=$(cat cicd_J_G | grep id | cut -d"'" -f 2)
echo "Retrieved git_from_jenkins group ID: ${j_g_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $j_g_id \
    --cclientid Jenkins \
    --rolename jenkins-git 

echo "Added roles to git_from_jenkins."
toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Retrieved Toolbox Admins group ID: ${toolbox_admin_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Jenkins \
    --rolename jenkins-admin 

echo "Added roles to Toolbox Admins."
tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Designer Group ID: ${tool_dev_designer_id}" 

#adding client roles to the group
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

echo "Added roles to Tooling Designer."
tool_ops_oper_id=$(cat TOOL_OPS_OPER | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Operator group ID: ${tool_ops_oper_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_oper_id \
    --cclientid Jenkins \
    --rolename jenkins-user \
    --rolename jenkins-oscicd-run \
    --rolename jenkins-ostest-run \
    --rolename jenkins-osdeploy-run

echo "Added roles to Tooling Operator."
tool_ops_spec_id=$(cat TOOL_OPS_SPEC | grep id | cut -d"'" -f 2)
echo "Retrieved Tooling Specialist group ID: ${tool_ops_spec_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $tool_ops_spec_id \
    --cclientid Jenkins \
    --rolename jenkins-user \
    --rolename jenkins-oscicd-run \
    --rolename jenkins-ostest-run \
    --rolename jenkins-osdeploy-run

echo "Added roles to Tooling Specialist."
