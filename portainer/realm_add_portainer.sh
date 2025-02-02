#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
# ./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user ${local_admin_user} --password ${local_admin_password}
# echo "Credentials created"

#Add Portainer client
./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Portainer" \
    -s description="System to manage containers in the toolchain" \
    -s clientId=Portainer \
    -s enabled=true \
    -s publicClient=false \
    -s serviceAccountsEnabled=true \
    -s fullScopeAllowed=false \
    -s standardFlowEnabled=true \
    -s frontchannelLogout=true \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=http://portainer.monitoring.provider.test:9000 \
    -s adminUrl=http://portainer.monitoring.provider.test:9000/ \
    -s 'redirectUris=[ "http://portainer.monitoring.provider.test:9000/*" ]' \
    -s 'webOrigins=[ "http://portainer.monitoring.provider.test:9000/" ]' \
    -o --fields id >cicdtoolbox_PORTAINER

# output is Created new client with id, we now need to grep the ID out of it
PORTAINER_ID=$(cat cicdtoolbox_PORTAINER | grep id | cut -d'"' -f 4)

# Create Client secret
./kcadm.sh create clients/$PORTAINER_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$PORTAINER_ID/client-secret -r cicdtoolbox >cicdtoolbox_portainer_secret
PORTAINER_token=$(grep value cicdtoolbox_portainer_secret | cut -d '"' -f4)

# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source in Portainer for Keycloak
echo "PORTAINER_token: ${PORTAINER_token}"

# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$PORTAINER_ID/roles -r cicdtoolbox -s name=PORTAINER-admin -s description='The admin role for Portainer'
echo "Portainer configuration finished"

# We need to add the portainer-admin claim and portainer-group claim to the token
./kcadm.sh create clients/$PORTAINER_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=group-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-usermodel-client-role-mapper \
    -s consentRequired=false \
	-s config="{\"multivalued\" : \"true\",\"userinfo.token.claim\" : \"true\",\"id.token.claim\" : \"true\",\"access.token.claim\" : \"true\",\"claim.name\" : \"portainerGroups\",\"jsonType.label\" : \"String\",\"usermodel.clientRoleMapping.clientId\" : \"Portainer\"}"

echo "Created role-group mapper in the Client Scope" 

# # We need to add a client scope on the realm for Portainer in order to include the audience in the access token
# ./kcadm.sh create -x "client-scopes" -r cicdtoolbox -s name=portainer-audience -s protocol=openid-connect &>cicdtoolbox_PORTAINER_SCOPE
# PORTAINER_SCOPE_ID=$(cat cicdtoolbox_PORTAINER_SCOPE | grep id | cut -d"'" -f 2)
# echo "Created Client scope for Portainer with id: ${PORTAINER_SCOPE_ID}" 

# Create a mapper for the audience
./kcadm.sh create clients/$PORTAINER_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=portainer-audience-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-audience-mapper \
    -s consentRequired=false \
	-s config="{\"included.client.audience\" : \"https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/realms/cicdtoolbox\",\"id.token.claim\" : \"false\",\"access.token.claim\" : \"true\"}"

# echo "Created audience mapper in the Client Scope" 

