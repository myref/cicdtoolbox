#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#Add Portainer client
PORTAINER_ID=$(./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="Portainer" \
    -s description="System to manage containers in the toolchain" \
    -s clientId=Portainer \
    -s surrogateAuthRequired=false \
    -s enabled=true \
    -s clientAuthenticatorType="client-secret" \
    -s 'redirectUris=[ "https://portainer.monitoring.provider.test:9443*" ]' \
    -s 'webOrigins=[ "https://portainer.monitoring.provider.test:9443/" ]' \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=false \
    -s publicClient=false \
    -s frontchannelLogout=true \
    -s protocol="openid-connect" \
    -s attributes="{ \
        \"realm_client\": \"false\", \
        \"oidc.ciba.grant.enabled\": \"false\", \
        \"frontchannel.logout.session.required\": \"true\", \
        \"post.logout.redirect.uris\": \"https://portainer.monitoring.provider.test:9443*\", \
        \"display.on.consent.screen\": "false", \
        \"oauth2.device.authorization.grant.enabled\": \"true\" \
       }" \
    -s fullScopeAllowed=false \
    -s rootUrl=https://portainer.monitoring.provider.test:9443 \
    -s adminUrl=https://portainer.monitoring.provider.test:9443/ \
    -o --fields id | grep id | cut -d'"' -f 4)

echo "Created Portainer client with ID: ${PORTAINER_ID}" 

# Create Client secret
./kcadm.sh create clients/$PORTAINER_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
PORTAINER_token=$(./kcadm.sh get clients/$PORTAINER_ID/client-secret -r cicdtoolbox | grep value | cut -d '"' -f4)

# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source in Portainer for Keycloak
echo "PORTAINER_token: ${PORTAINER_token}"

# Now we can add client specific roles (Clientroles)
./kcadm.sh create clients/$PORTAINER_ID/roles -r cicdtoolbox -s name=local-admin -s description='The admin role for Portainer'
echo "Portainer configuration finished"

# We need to add the portainer-admin claim and portainer-group claim to the token
./kcadm.sh create clients/$PORTAINER_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=portainer-group-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-usermodel-client-role-mapper \
    -s consentRequired=false \
	-s config="{\"multivalued\" : \"true\",\"userinfo.token.claim\" : \"true\",\"id.token.claim\" : \"true\",\"access.token.claim\" : \"true\",\"claim.name\" : \"portainerGroups\",\"jsonType.label\" : \"String\",\"usermodel.clientRoleMapping.clientId\" : \"Portainer\"}"

echo "Created role-group mapper in the Client Scope" 

# We need to add a client scope on the realm for Portainer in order to include the audience in the access token
PORTAINER_SCOPE_ID=$(./kcadm.sh create -x "client-scopes" -r cicdtoolbox -s name=portainer-audience -s protocol=openid-connect | grep id | cut -d"'" -f 2)
echo "Created Client scope for Portainer with id: ${PORTAINER_SCOPE_ID}" 

# Create a mapper for the audience
./kcadm.sh create clients/$PORTAINER_ID/protocol-mappers/models \
    -r cicdtoolbox \
	-s name=portainer-audience-mapper \
    -s protocol=openid-connect \
	-s protocolMapper=oidc-audience-mapper \
    -s consentRequired=false \
	-s config="{\"included.client.audience\" : \"https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/realms/cicdtoolbox\",\"id.token.claim\" : \"false\",\"access.token.claim\" : \"true\"}"

echo "Created audience mapper in the Client Scope" 

toolbox_admin_id=$(cat TOOLBOX_ADMIN | grep id | cut -d"'" -f 2)
echo "Retrieved Toolbox Admins group ID: ${toolbox_admin_id}" 

#adding client roles to the group
./kcadm.sh add-roles \
    -r cicdtoolbox \
    --gid $toolbox_admin_id \
    --cclientid Portainer \
    --rolename local-admin 
