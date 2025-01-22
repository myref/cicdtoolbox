*** Settings ***
Resource          ../install_test.resource

Documentation       Making sure that Jenkins has access to the myapp-os repository on gitea

Suite Setup       Open Browser   ${JENKINS URL}      ${BROWSER1}       remote_url=http://seleniumgchost.internal.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:4444    options=add_argument("--ignore-certificate-errors")
Suite Teardown    Close Browser

*** Variables ***
${JENKINS URL}      https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/
${JENKINS NetCICD}  https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/job/Infraautomator/computation/console
${JENKINS LOGOUT}   https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/logout 

*** Test cases ***
Log into Jenkins
    Log into Jenkins as netcicd

Open infraautomator organization
    Get infraautomator repositories


*** Keywords ***
Log into Jenkins as netcicd
    Set Window Size             2560                 1920
    Go To                       ${JENKINS URL}
    Set Selenium Speed          ${DELAY}
    Keycloak Page Should Be Open
    Input Text                  username              netcicd
    Input Text                  password              ${VALID_PASSWORD}
    Submit Credentials
    Jenkins Page Should Be Open

Get infraautomator repositories
    Go To                       https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/job/Infraautomator/computation/console

    ${repo_status}=             Run Keyword And Return Status    Page Should Contain        Finished: SUCCESS

    IF  ${repo_status}
        Log to Console          Infraautomator organization found
        ${netcicd_status}=      Run Keyword And Return Status    Page Should Contain        myapp-os

        IF  ${netcicd_status}
            Log to Console      myapp-os repository found
        ELSE
            Log to Console      myapp-os repository *NOT* found
            Fail
        END

        ${toolbox_status}=      Run Keyword And Return Status    Page Should Contain        myapp-deploy

        IF  ${toolbox_status}
            Log to Console      myapp-deploy repository found
        ELSE
            Log to Console      myapp-deploy repository *NOT* found
            Fail
        END
    ELSE
        Log to Console          Infraautomator organization *NOT* found
        Fail
    END

Jenkins Page Should Be Open
    Location Should Contain     ${JENKINS URL}
    Title Should Be             Dashboard [Jenkins]
