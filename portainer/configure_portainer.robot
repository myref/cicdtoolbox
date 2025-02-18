*** Settings ***
Library                               SeleniumLibrary
Library                               OperatingSystem
Library                               XML
Documentation                         Setting up Portainer

Suite Setup       Open Browser   ${URL}      ${BROWSER1}       remote_url=http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***
Set local-admin name 
    Set Admin credentials
    
Configure Portainer
    Choose environment

*** Variables ***

${BROWSER1}                            chrome
${DELAY}                               0
${URL}                                 http://portainer.monitoring.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:9000
${SSL_URL}                             https://portainer.monitoring.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:9443
${KEYCLOAK_URL}                        https://keycloak.services.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8443
${PORTAINER_ADMIN}                     %{local_admin_user}
${PORTAINER_ADMIN_PASSWORD}            %{local_admin_password}

*** Keywords ***
Set Admin credentials
    Wait Until Page Contains           New Portainer installation
    Input Text                         username                ${PORTAINER_ADMIN}
    Input Text                         password                ${PORTAINER_ADMIN_PASSWORD}${PORTAINER_ADMIN_PASSWORD}
    Input Text                         confirm_password        ${PORTAINER_ADMIN_PASSWORD}${PORTAINER_ADMIN_PASSWORD}
    Click Element                      toggle_enableTelemetry
    Click Element                      xpath://*[text()='Create user']

Choose environment
    Wait Until Page Contains           Environment Wizard
    Go To                              ${URL}/#!/settings/auth
    Click Element                      xpath://*[text()='OAuth']
    Scroll Element Into View           oauth_client_id
    Input Text                         oauth_client_id            Portainer
    Scroll Element Into View           oauth_client_secret
    Input Text                         oauth_client_secret        %{portainer_secret}
    Scroll Element Into View           oauth_authorization_uri
    Input Text                         oauth_authorization_uri    ${KEYCLOAK_URL}/realms/cicdtoolbox/protocol/openid-connect/auth
    Scroll Element Into View           oauth_access_token_uri
    Input Text                         oauth_access_token_uri     ${KEYCLOAK_URL}/realms/cicdtoolbox/protocol/openid-connect/token
    Scroll Element Into View           oauth_resource_uri
    Input Text                         oauth_resource_uri         ${KEYCLOAK_URL}/realms/cicdtoolbox/protocol/openid-connect/userinfo
    Scroll Element Into View           oauth_redirect_uri
    Input Text                         oauth_redirect_uri         ${SSL_URL}
    Scroll Element Into View           oauth_logout_url
    Input Text                         oauth_logout_url           ${KEYCLOAK_URL}/realms/cicdtoolbox/protocol/openid-connect/logout
    Scroll Element Into View           oauth_user_identifier
    Input Text                         oauth_user_identifier      email
    Scroll Element Into View           oauth_scopes
    Input Text                         oauth_scopes               openid
    Scroll Element Into View           xpath://*[text()='Save settings']
    Click Element                      xpath://*[text()='Save settings']

