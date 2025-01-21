*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           DebugLibrary
Documentation     Creating jenkins-jenkins token

Suite Setup       Open Browser   ${JENKINS URL}      ${BROWSER1}       remote_url=http://seleniumgchost.internal.provider.test:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***

Create Jenkins token
    Log into Jenkins as jenkins-jenkins
    Create jenkins-jenkins token
    Click Jenkins Logout Link

Enter Jenkins token in credentials
    Log into Jenkins as netcicd
    Change jenkins-jenkins credentials 
    Click Jenkins Logout Link
    
Close browsers
    Close Browser

*** Variables ***

${BROWSER1}         chrome

${DELAY}            0
${JENKINS URL}      https://jenkins.tooling.provider.test:8084/
${JENKINS LOGOUT}   https://jenkins.tooling.provider.test:8084/logout 

*** Keywords ***   
Log into Jenkins as jenkins-jenkins
    Set Window Size             2560                 1920 
    Go To                       ${JENKINS URL}
    Set Selenium Speed          ${DELAY}
    Keycloak Page Should Be Open
    Input Text                  username              jenkins-jenkins
    Input Text                  password              ${VALID_PASSWORD}
    Submit Credentials
    Jenkins Page Should Be Open
    Log to Console              Successfully logged in to Jenkins as jenkins-jenkins

Create jenkins-jenkins token
    Go To                       https://jenkins.tooling.provider.test:8084/user/jenkins-jenkins/security
    Click Button                Add new Token
    Click Button                Generate
    Wait Until Page Contains Element                 class:new-token-value.visible
    ${TOKEN}                    Get Text             class:new-token-value.visible
    Set Suite Variable          ${TOKEN}
    Wait Until Page Contains Element                 class:jenkins-button.jenkins-button--primary
    Click Button                class:jenkins-button.jenkins-button--primary
    Log to Console              Token created
    Create File                 ${EXECDIR}/jtoken.txt   ${TOKEN}

Log into Jenkins as netcicd
    Keycloak Page Should Be Open
    Input Text                  username              netcicd
    Input Text                  password              ${VALID_PASSWORD}
    Submit Credentials
    Jenkins Page Should Be Open
    Capture Page Screenshot

Change jenkins-jenkins credentials 
    Go To                       https://jenkins.tooling.provider.test:8084/credentials/store/system/domain/_/credential/jenkins-jenkins/update
    Click Button                class:hidden-password-update.hidden-password-update-btn.jenkins-button.jenkins-button--primary
    Input Text                  name:_.password       ${TOKEN}
    Click Button                Save
    Log to Console              jenkins-jenkins credentials changed in Jenkins

Enter Jenkins token in Jenkins credentials
    Go To                       ${JENKINS URL}
    Log into Jenkins as netcicd
    Go To                       https://jenkins.tooling.provider.test:8084/credentials/store/system/domain/_/credential/jenkins-git/update
    Click Button                Change Password
    Input Text                  name:_.password         ${SA_TOKEN_text}
    Click Button                Save
    Log to Console              jenkins-git changed credentials to login to Gitea

Keycloak Page Should Be Open
    Wait Until Page Contains    Sign in to
    Title Should Be             Sign in to Welcome to your Development Toolkit

Jenkins Page Should Be Open
    Wait Until Page Contains    Dashboard
    Location Should Contain     ${JENKINS URL}
    Title Should Be             Dashboard [Jenkins]

Click Jenkins Logout Link
    Go To                       ${JENKINS LOGOUT}
    Keycloak Page Should Be Open
    Sleep                       10
    Capture Page Screenshot

Submit Credentials
    Click Button                kc-login
