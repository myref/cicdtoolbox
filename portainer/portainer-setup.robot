*** Settings ***
Library                               SeleniumLibrary
Library                               OperatingSystem
Library                               XML
Documentation                         Setting up Hashicorp Vault

Suite Setup       Open Browser   ${URL}      ${BROWSER1}       remote_url=http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***
Set local-admin name 
    Set Admin credentials
    
Configure Portainer
    Choose environment
Get unseal keys and token
    Get keys

Sign in to Vault 
    Unseal Vault
    Sign in to vault

Set up PKI
    Enable PKI engine

Set up KV
    Enable Key Value Store

*** Variables ***

${BROWSER1}                            chrome
${DELAY}                               0
${URL}                                 http://portainer.monitoring.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:9000
${PORTAINER_ADMIN}                     %{local_admin_user}
${PORTAINER_ADMIN_PASSWORD}            %{local_admin_password}

*** Keywords ***
Set Admin credentials
    Wait Until Page Contains           New Portainer installation
    Input Text                         username                ${PORTAINER_ADMIN}
    Input Text                         password                ${PORTAINER_ADMIN_PASSWORD}${PORTAINER_ADMIN_PASSWORD}
    Input Text                         confirm-password        ${PORTAINER_ADMIN_PASSWORD}${PORTAINER_ADMIN_PASSWORD}
    Click Element                      toggle_enableTelemetry
    Click Button                       Create user

Choose environment
    Wait Until Page Contains           Environment Wizard
    Click Button                       Get started
    Go To                              ${URL}/#!/settings
    Run Keyword And Ignore Error       Scroll Element Into View    /html/body/div/div[2]/div/div/settings-view/div[2]/div[4]/div[1]/div/span[1]/span          
    Click Element                      toggle_forceHTTPS
    
    Go To                              ${URL}/#!/settings/auth
    Scroll Element Into View           




























Get keys                              
    Wait Until Element Is Visible      xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/div[1]/div[2]/div/div/div/button[1]    timeout=300s
    ${token}                           SeleniumLibrary.Get Element Attribute    xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/div[1]/div[2]/div/div/div/button[1]    data-clipboard-text                                  
    Set Global Variable                ${token}
    Create File                        ${EXECDIR}/vault/token.txt   ${token}
    ${key}                             SeleniumLibrary.Get Element Attribute    xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/div[1]/div[3]/div/div/div/button[1]    data-clipboard-text
    Set Global Variable                ${key}
    Create File                        ${EXECDIR}/vault/key.txt   ${key}
    Click Link                         Continue to Unseal

Unseal Vault 
    Wait Until Page Contains           Unseal Vault 
    Input Text                         key                    ${key}
    Click Element                      xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/form/div[2]/div/div[1]/button

Sign in to vault    
    Wait Until Page Contains           Sign in to Vault 
    Input Text                         token                      ${token}
    Click Button                       auth-submit    

Enable PKI engine
    Wait Until Page Contains           Secrets Engines
    Click Element                      xpath:/html/body/div[1]/div/div[2]/div[1]/section/div/nav/div/nav/a/span
    Wait Until Page Contains           Enable a Secrets Engine
    Click Element                      xpath://*[@id="pki"]
    Wait Until Element Is Visible      xpath:/html/body/div[1]/div/div[2]/div[1]/section/div/div/form/div[2]/button
    Click Button                       Next
    Wait Until Page Contains           Enable PKI Certificates Secrets Engine
    Click Button                       xpath:/html/body/div[1]/div/div[2]/div[1]/section/div/div/form/div[2]/div[1]/button
    Click Link                         Secrets

Enable Key Value Store
    Wait Until Page Contains           Secrets Engines
    Click Element                      xpath:/html/body/div[1]/div/div[2]/div[1]/section/div/nav/div/nav/a/span
    Wait Until Page Contains           Enable a Secrets Engine
    Click Element                      xpath://*[@id="kv"]
    Click Element                      xpath://*[@class="columns is-mobile is-variable is-1"]
    Click Button                       Next
    Wait Until Page Contains           Enable KV Secrets Engine
    Click Button                       xpath:/html/body/div[1]/div/div[2]/div[1]/section/div/div/form/div[2]/div[1]/button
    Click Link                         Secrets
