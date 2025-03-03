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

./kcadm.sh create groups -r cicdtoolbox -s name="cicd_agents" &>cicd_AGENTS
cicd_agents_id=$(cat cicd_AGENTS | grep id | cut -d"'" -f 2)
echo "Created cicdtoolbox Agents with ID: ${cicd_agents_id}" 

./kcadm.sh create groups -r cicdtoolbox -s name="git_from_jenkins" &>cicd_J_G
j_g_id=$(cat cicd_J_G | grep id | cut -d"'" -f 2)
echo "Created git_from_jenkins group with ID: ${j_g_id}" 

./kcadm.sh create groups -r cicdtoolbox -s name="toolbox_admin" &>TOOLBOX_ADMIN
toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Created Toolbox Admins group with ID: ${toolbox_admin_id}" 

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_dev_design" &>TOOL_DEV_DESIGNER
tool_dev_designer_id=$(cat TOOL_DEV_DESIGNER | grep id | cut -d"'" -f 2)
echo "Created Tooling Designer Group with ID: ${tool_dev_designer_id}" 

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_ops_oper" &>TOOL_OPS_OPER
tool_ops_oper_id=$(cat TOOL_OPS_OPER | grep id | cut -d"'" -f 2)
echo "Created Tooling Operator group within the Tooling Operations Department with ID: ${tool_ops_oper_id}" 

./kcadm.sh create groups -r cicdtoolbox -s name="tooling_ops_spec" &>TOOL_OPS_SPEC
tool_ops_spec_id=$(cat TOOL_OPS_SPEC | grep id | cut -d"'" -f 2)
echo "Created Tooling Specialist group within the Tooling Operations Department with ID: ${tool_ops_spec_id}" 

# Add MSP_IDP integration for MSP_IDP, needs to be last, otherwise LDAP groups interfere with group creation in Keycloak
msp_idp_ldap_id=$(./kcadm.sh create components -r cicdtoolbox \
    -s name=msp_idp \
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
    -s "config.connectionUrl=[\"ldap://msp-idp.iam.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3890\"]" \
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
    -s 'config.fullSyncPeriod=["10"]' \
    -o --fields id | grep id | cut -d'"' -f 4)

echo "Created MSP_IDP with ID: ${msp_idp_ldap_id}"  

./kcadm.sh create components -r cicdtoolbox \
    -s name=groups \
    -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
    -s parentId=$msp_idp_ldap_id \
    -s "config.\"groups.dn\"=[\"ou=groups,dc=${DOMAIN_NAME_SL},dc=${DOMAIN_NAME_TL}\"]" \
    -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["groupOfUniqueNames"]' \
    -s 'config.mode=["READ_ONLY"]'

echo "MSP_IDP configured"
#Now delete tokens and secrets
rm cicdtoolbox_*
