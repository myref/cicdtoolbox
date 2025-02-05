*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           DebugLibrary
Documentation     Save Jenkins configuration

Suite Setup       Stage the tooling
Suite Teardown    Close Browser

*** Test cases ***
Store configuration of Jenkins
    Log into a system via keycloak                 ${JENKINS URL}     netcicd    %{default_user_password}
    Create updated CASC file


*** Variables ***
${BROWSER1}         chrome
${DELAY}            0
${JENKINS URL}      https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/
${JENKINS LOGOUT}   https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/logout
${TEST_HOST}        http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444

*** Keywords ***   
Stage the tooling
    Log To Console              message=Test ${JENKINS URL} on ${TEST_HOST} with browser ${BROWSER1} and password %{default_user_password}
    Open Browser                ${JENKINS URL}       ${BROWSER1}        remote_url=${TEST_HOST}       options=add_argument("--ignore-certificate-errors")
    Set Window Size             1920                 1440 
    Set Selenium Speed          ${DELAY}


Log into a system via keycloak
    [Arguments]                 ${system}    ${user}    ${password}
    Go To                       ${system}
    Keycloak Page Should Be Open
    Input Text                  username              ${user}
    Input Text                  password              ${password}
    Submit Credentials
    Log to Console              Successfully logged in to ${system} as ${user}
    Capture Page Screenshot

Keycloak Page Should Be Open
    Wait Until Page Contains    Sign in to
    Title Should Be             Sign in to Welcome to your Development Toolkit

Submit Credentials
    Click Button                kc-login

Jenkins Page Should Be Open
    Wait Until Page Contains    Dashboard
    Location Should Contain     ${JENKINS URL}
    Title Should Be             Dashboard [Jenkins]

Click Jenkins Logout Link
    Go To                       ${JENKINS LOGOUT}
    Keycloak Page Should Be Open
    Capture Page Screenshot

Create updated CASC file
    Go To                       ${JENKINS URL}manage/configuration-as-code
    Click Button                View Configuration
    Sleep                       1
    ${CONFIG}                   Get Text               xpath=//pre[@class='language-yaml']
    Log to Console              Configuration file downloaded
    Capture Page Screenshot
    Create File                 ${EXECDIR}/jenkins/casc.yaml   ${CONFIG}