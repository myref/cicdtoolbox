*** Settings ***
Resource          ../install_test.resource

Documentation       Making sure that Jenkins has access to the OsCICD repository on gitea

Suite Setup       Open Browser   ${JENKINS URL}      ${BROWSER}       remote_url=http://seleniumgchost.internal.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Variables ***
${JENKINS URL}      https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/
${JENKINS NetCICD}  https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/job/%{ORG_NAME}/computation/console
${JENKINS LOGOUT}   https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/logout 
${ORG}              %{ORG_NAME}

*** Test cases ***
Log into Jenkins
    Log into Jenkins as netcicd

Open organization
    Get repositories


*** Keywords ***
Log into Jenkins as netcicd
    Set Window Size             2560                 1920
    Go To                       ${JENKINS URL}
    Set Selenium Speed          ${DELAY}
    Keycloak Page Should Be Open
    Input Text                  username              netcicd
    Input Text                  password              %{default_user_password}
    Submit Credentials
    Jenkins Page Should Be Open

Get repositories
    Go To                       https://jenkins.tooling.%{DOMAIN_NAME_SL}.%{DOMAIN_NAME_TL}:8084/job/${ORG}/computation/console

    ${repo_status}=             Run Keyword And Return Status    Page Should Contain        Finished: SUCCESS

    IF  ${repo_status}
        Log to Console          ${ORG} organization found
        ${netcicd_status}=      Run Keyword And Return Status    Page Should Contain        OsCICD

        IF  ${netcicd_status}
            Log to Console      OsCICD repository found
        ELSE
            Log to Console      OsCICD repository *NOT* found
            Fail
        END

        ${toolbox_status}=      Run Keyword And Return Status    Page Should Contain        OsDeploy

        IF  ${toolbox_status}
            Log to Console      OsDeploy repository found
        ELSE
            Log to Console      OsDeploy repository *NOT* found
            Fail
        END
    ELSE
        Log to Console          ${ORG} organization *NOT* found
        Fail
    END

Jenkins Page Should Be Open
    Location Should Contain     ${JENKINS URL}
    Title Should Be             Dashboard [Jenkins]
