*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library    XML
Documentation     Unseal Hashicorp Vault

Suite Setup       Open Browser   ${URL}      ${BROWSER}       remote_url=http://seleniumffhost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***
Log in to vault
    Open vault site

Sign in to Vault 
    Unseal Vault

*** Variables ***

${BROWSER}         headlessfirefox
${DELAY}            0
${URL}              https://vault.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8200

*** Keywords ***
Open vault site
    Set Window Size                    2560                 1920 
    Wait Until Page Contains           Unseal Vault


Unseal Vault 
    Page Should Contain        Unseal Vault 
    Input Text                 key                    ${key}
    Click Element              xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/form/div[2]/div/div[1]/button
