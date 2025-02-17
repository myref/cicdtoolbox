#!/bin/bash +x

# shell script to be copied into $KEYCLOAK_HOME/bin
cd $HOME/bin

#Create credentials
./kcadm.sh config credentials --server https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443 --realm master --user $1 --password $2
echo "Credentials created"

#Add Build_dev node
BUILD_ID=$(./kcadm.sh create clients \
    -r cicdtoolbox \
    -s name="build_$3" \
    -s description="First step build node for Jenkins for $4 jobs" \
    -s clientId=build_$3 \
    -s enabled=true \
    -s publicClient=false \
    -s fullScopeAllowed=false \
    -s directAccessGrantsEnabled=true \
    -s rootUrl=https://build_$3.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} \
    -s adminUrl=https://build_$3.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/ \
    -s "redirectUris=[\"https://build_$3.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/user/oauth2/keycloak/callback\" ]" \
    -s "webOrigins=[\"https://build_$3.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3100/\" ]" \
    -o --fields id | grep id | cut -d'"' -f 4)

echo "Created cicdtoolbox_build_$3 client with ID: ${BUILD_ID}" 

# Create Client secret
./kcadm.sh create clients/$BUILD_ID/client-secret -r cicdtoolbox

# We need to retrieve the token from keycloak for this client
./kcadm.sh get clients/$BUILD_ID/client-secret -r cicdtoolbox >cicdtoolbox_build_dev_secret
BUILD_token=$(grep value cicdtoolbox_build_dev_secret | cut -d '"' -f4)
# Make sure we can grep the clienttoken easily from the keycloak_create.log to create an authentication source for Keycloak
echo "Build_$3_token: ${BUILD_token}"
echo "Build_$3 configuration finished"
