#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#add realm
./kcadm.sh create realms \
    -s realm=cust1-idp \
    -s id=cust1-idp \
    -s enabled=true \
    -s displayName="Customer1 Identity Provider" \
    -s displayNameHtml="<b>Customer1 Identity Provider</b>"
echo "Cust1-idp realm created"

# Add CUST1_IDP integration for CUST1_IDP, needs to be last, otherwise LDAP groups interfere with group creation in Keycloak
cust1_idp_ldap_id=$(./kcadm.sh create components -r cust1-idp \
    -s name=cust1_idp \
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
    -s "config.connectionUrl=[\"ldap://cust1-idp.iam.${CUST1_DOMAIN_NAME_SL}.${CUST1_DOMAIN_NAME_TL}:3890\"]" \
    -s "config.usersDn=[\"ou=people,dc=${CUST1_DOMAIN_NAME_SL},dc=${CUST1_DOMAIN_NAME_TL}\"]" \
    -s 'config.searchScope=["1"]' \
    -s 'config.authType=["simple"]' \
    -s "config.bindDn=[\"uid=admin,ou=people,dc=${CUST1_DOMAIN_NAME_SL},dc=${CUST1_DOMAIN_NAME_TL}\"]" \
    -s 'config.bindCredential=["'$3'"]' \
    -s 'config.useTruststoreSpi=["ldapsOnly"]' \
    -s 'config.pagination=["false"]' \
    -s 'config.connectionPooling=["true"]' \
    -s 'config.useKerberosForPasswordAuthentication=["false"]' \
    -s 'config.batchSizeForSync=["1000"]' \
    -s 'config.fullSyncPeriod=["10"]'  \
    -o --fields id | grep id | cut -d'"' -f 4)

echo "Created CUST1_IDP with ID: ${cust1_idp_ldap_id}"  

./kcadm.sh create components -r cust1-idp \
    -s name=groups \
    -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
    -s parentId=$cust1_idp_ldap_id \
    -s "config.\"groups.dn\"=[\"ou=groups,dc=${CUST1_DOMAIN_NAME_SL},dc=${CUST1_DOMAIN_NAME_TL}\"]" \
    -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["groupOfUniqueNames"]' \
    -s 'config.mode=["READ_ONLY"]'

echo "CUST1_IDP configured"

