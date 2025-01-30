*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           DebugLibrary
Documentation     Creating Jenkins tokens

Suite Setup       Stage the tooling
Suite Teardown    Close Browser

*** Test cases ***

Create Jenkins token
    Log into a system via keycloak                 ${JENKINS URL}     jenkins-jenkins    %{default_user_password}
    Create jenkins-jenkins token
    Click Jenkins Logout Link
    Close Browser

Enter Jenkins token in credentials
    Stage the tooling
    Log into a system via keycloak                 ${JENKINS URL}     netcicd            %{default_user_password}
    Change jenkins-jenkins credentials 
 
Enable Jenkins to log into git
    Login to Gitea as Jenkins
    Create Jenkins token in Gitea
    Enter Gitea token in Jenkins credentials

Activate organisation
    Confirm organisation configuration

Get Agent Secrets
    Get Jenkins agent secret    Dev
    Get Jenkins agent secret    Test
    Get Jenkins agent secret    Acc
    Get Jenkins agent secret    Prod


*** Variables ***
${BROWSER1}         chrome
${DELAY}            0
${JENKINS URL}      https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/
${JENKINS LOGOUT}   https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/logout
${GITEA URL}        https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000
${GITEA LOGIN}      https://gitea.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:3000/user/login?redirect_to=%2f

*** Keywords ***   
Stage the tooling
    Log To Console              message=Test  ${JENKINS URL} on http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444 with browser ${BROWSER1} and password %{default_user_password}
    Open Browser                ${JENKINS URL}       ${BROWSER1}        remote_url=http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444       options=add_argument("--ignore-certificate-errors")
    Set Window Size             1920                 1440 
    Set Selenium Speed          ${DELAY}

Create jenkins-jenkins token
    Go To                       https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/user/jenkins-jenkins/security
    Click Button                Add new Token
    Click Button                Generate
    Wait Until Page Contains Element                 class:new-token-value.visible
    ${TOKEN}                    Get Text             class:new-token-value.visible
    Set Suite Variable          ${TOKEN}
    Wait Until Page Contains Element                 class:jenkins-button.jenkins-button--primary
    Click Button                class:jenkins-button.jenkins-button--primary
    Log to Console              Token created
    Create File                 ${EXECDIR}/jtoken.txt   ${TOKEN}

Change jenkins-jenkins credentials 
    Go To                       https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/credentials/store/system/domain/_/credential/jenkins-jenkins/update
    Click Button                Change Password
    Input Text                  name:_.password       ${TOKEN}
    Click Button                Save
    Log to Console              jenkins-jenkins credentials changed in Jenkins

Login to Gitea as Jenkins
    Go To                       ${GITEA LOGIN}
    Input Text                  user_name             Jenkins
    Input Text                  password              %{default_user_password}
    Click Button                Sign In
    Input Text                  password              %{default_user_password}
    Input Text                  retype                %{default_user_password}
    Click Button                Update Password
    Log to Console              Jenkins changed password to token

Enter Gitea token in Jenkins credentials
    Go To                       https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/credentials/store/system/domain/_/credential/jenkins-git/update
    Click Button                Change Password
    Input Text                  name:_.password         ${SA_TOKEN_text}
    Click Button                Save
    Log to Console              jenkins-git changed credentials to login to Gitea

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
    Input Text                  old_password            %{default_user_password}
    Input Text                  password                ${SA_TOKEN_text}
    Input Text                  retype                  ${SA_TOKEN_text}
    Click Button                Update Password
    Log to Console              Jenkins password set to token

Get Jenkins agent secret
    [Arguments]                  ${stage}

    Go To                        https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/computer/${stage}/
    ${agent_page_content}        Get Text    xpath=//pre
    ${secretstuff}               Evaluate    re.split("-secret ", '''${agent_page_content}''', 1)[1]
    ${my_secret}                 Evaluate    re.split(" ", '''${secretstuff}''',1)[0]
    Log to Console               The ${stage} secret is: ${my_secret}
    Create File                  ${EXECDIR}/buildnode/${stage}_secret.txt   ${my_secret}

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

Confirm organisation configuration
    Go To                       ${JENKINS URL}/job/%{ORG_NAME}/configure
    Wait Until Page Contains    General
    Click Button                Save
    Log to Console              Organisation configuration confirmed
    Capture Page Screenshot
    Go To                       ${JENKINS URL}/job/%{ORG_NAME}/build?delay=0
    Go To                       ${JENKINS URL}/job/%{ORG_NAME}/computation/console
    Sleep                       5
    Go To                       ${JENKINS URL}/job/%{ORG_NAME}/computation/console
    
    Log to Console              Organisation configuration confirmed