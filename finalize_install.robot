*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           DebugLibrary
Documentation     Creating jenkins-jenkins token
...               Enabling gitea login from Jenkins

Suite Setup       Open Browser   ${JENKINS URL}      ${BROWSER1}       remote_url=http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Test cases ***

Enable Jenkins to log into git
    Login to Gitea as Jenkins
    Create Jenkins token in Gitea
    Enter Jenkins token in Jenkins credentials
    
Close browsers
    Close Browser

*** Variables ***

${BROWSER1}         chrome

${DELAY}            1
${JENKINS URL}      https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/
${JENKINS LOGOUT}   https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/logout 
${GITEA URL}        https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000
${GITEA LOGIN}      https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000/user/login?redirect_to=%2f

*** Keywords ***   
Login to Gitea as Jenkins
    Go To                       ${GITEA LOGIN}
    Input Text                  user_name             Jenkins
    Input Text                  password              ${VALID_PASSWORD}
    Click Button                Sign In
    Input Text                  password              ${VALID_PASSWORD}
    Input Text                  retype                ${VALID_PASSWORD}
    Click Button                Update Password
    Log to Console              Jenkins changed password to token

Create Jenkins token in Gitea
    Go To                       https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000/user/settings/applications
    Input Text                  name                    Jenkins
    
    Click Element               xpath://summary[contains(., "Select permissions")]

    Select From List By Label   access-token-scope-organization    Read
    Select From List By Label   access-token-scope-repository      Read and Write
    Select From List By Label   access-token-scope-notification    Read and Write

    Click Button                Generate Token     

    Wait Until Element Is Visible                       xpath:/html/body/div/div/div/div[2]/div[2]/p       
    ${SA_TOKEN_text}            Get Text                xpath:/html/body/div/div/div/div[2]/div[2]/p
    Set Global Variable         ${SA_TOKEN_text}
    Log to Console              Jenkins token created in Gitea

    Go To                       https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000/user/settings/account
    Input Text                  old_password            ${VALID_PASSWORD}
    Input Text                  password                ${SA_TOKEN_text}
    Input Text                  retype                  ${SA_TOKEN_text}
    Click Button                Update Password
    Log to Console              Jenkins password set to token

Enter Jenkins token in Jenkins credentials
    Go To                       ${JENKINS URL}
    Log into Jenkins as netcicd
    Go To                       https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/credentials/store/system/domain/_/credential/jenkins-git/update
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

Submit Credentials
    Click Button                kc-login
