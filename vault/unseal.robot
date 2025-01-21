*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library    XML
Documentation     Unseal Hashicorp Vault

Suite Setup       Open Browser   ${URL}      ${BROWSER1}       remote_url=http://seleniumffhost.internal.provider.test:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***
Log in to vault
    Open vault site

Sign in to Vault 
    Unseal Vault

*** Variables ***

${BROWSER1}         headlessfirefox
${DELAY}            0
${URL}              https://vault.internal.provider.test:8200

*** Keywords ***
Open vault site
    Set Window Size                    2560                 1920 
    Wait Until Page Contains           Unseal Vault


Unseal Vault 
    Page Should Contain        Unseal Vault 
    Input Text                 key                    ${key}
    Click Element              xpath:/html/body/div[1]/div/div[2]/div[1]/div/div/div/div[3]/form/div[2]/div/div[1]/button
