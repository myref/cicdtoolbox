#!/bin/bash
user=$2
pwd=$1

#First define functions

function CreateRepo () {   
    echo "****************************************************************************************************************"
    echo " Creating ${2} repo under ${1} organization"
    echo "****************************************************************************************************************"
    local repo_payload='{
        "auth_password": "string",  
        "auth_token": "string",  
        "auth_username": "string",  
        "clone_addr": "'$3'",  
        "description": "'$4'",  
        "issues": false,  
        "labels": false,  
        "milestones": false,  
        "mirror": false,  
        "private": true,  
        "pull_requests": false,  
        "releases": false,  
        "repo_name": "'$2'",  
        "repo_owner": "'$1'",  
        "service": "git",  
        "uid": 0,  
        "wiki": false
        }'
    curl -s --insecure --user $user:$pwd -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/repos/migrate" -H  "accept: application/json" -H  "Content-Type: application/json" -d "${repo_payload}"
    echo " "
    echo "****************************************************************************************************************"
    echo " Creating webhook for the ${2} repo"
    echo "****************************************************************************************************************"
    local webhook_payload='{
        "active": true,
        "branch_filter": "*",
        "config": {
            "content_type": "json",
            "url": "https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/gitea-webhook/post"
            },
        "events": [ "push" ],
        "type": "gitea"
        }'
    curl -s --insecure --user $user:$pwd -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/repos/${1}/${2}/hooks" -H  "accept: application/json" -H  "Content-Type: application/json" -d "${webhook_payload}"
    echo " "    
}

function CreateTeam () {
    echo "****************************************************************************************************************"
    echo " Creating ${2} team in Gitea "
    echo "****************************************************************************************************************"
    local team_payload='{ 
        "can_create_org_repo": false, 
        "description": "'$3'", 
        "includes_all_repositories": false, 
        "name": "'$2'", 
        "permission": "'$4'", 
        "units": [ 
            "repo.code", 
            "repo.issues", 
            "repo.ext_issues", 
            "repo.wiki", 
            "repo.pulls", 
            "repo.releases", 
            "repo.projects",
            "repo.ext_wiki" 
            ] 
        }'
    local team_data=$(curl -s --insecure --user $user:$pwd -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/orgs/${1}/teams" -H "accept: application/json" -H "Content-Type: application/json" -d "${team_payload}")
    local team_id=$( echo $team_data | awk -F',' '{print $(1)}' | awk -F':' '{print $2}' )
    echo " "
    echo "****************************************************************************************************************"
    echo " Adding ${5} repo to ${2} team in Gitea "
    echo "****************************************************************************************************************"
    curl -s --insecure --user $user:$pwd -X PUT "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/teams/${team_id}/repos/infraautomator/${5}" -H  "accept: application/json"
    echo " "

    team=$team_id
}
echo "****************************************************************************************************************"
echo " Cleaning Gitea" 
echo "****************************************************************************************************************"
rm -f gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}*
sudo rm -rf data/*
echo " " 
echo "****************************************************************************************************************"
echo " Ensure reachability of Gitea through the hosts file"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "gitea" /etc/hosts; then
    echo " Gitea exists in /etc/hosts, removing..."
    sudo sed -i '/gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d' /etc/hosts
fi
echo " Add Gitea to /etc/hosts"
sudo echo "172.16.11.3   gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Saving gitea certificates"
echo "****************************************************************************************************************"
pwd
cp vault/certs/gitea* gitea/

DOCKER_BUILDKIT=1 docker compose --project-name cicd-toolbox up -d --build --no-deps gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
echo " "
echo "****************************************************************************************************************"
echo " Installing CA certificate"
echo "****************************************************************************************************************"
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/usr/sbin/update-ca-certificates"
echo " "
echo "****************************************************************************************************************"
echo " Wait until Gitea has started"
echo "****************************************************************************************************************"
docker restart gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
until $(curl --output /dev/null --silent --head --insecure --fail https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000); do
    printf '.'
    sleep 5
done
echo " "
echo "****************************************************************************************************************"
echo " Create local gituser (admin role: $user)"
echo "****************************************************************************************************************"
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "su git -c '/usr/local/bin/gitea admin user create --username $user --password $pwd --admin --email gitea-local-admin@tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}'"
echo " "
echo "****************************************************************************************************************"
echo " Creating InfraAutomators organization in Gitea "
echo "****************************************************************************************************************"
ORG_PAYLOAD='{ 
    "description": "Infrastructure automation transformation team", 
    "full_name": "InfraAutomators", 
    "location": "Github",
    "repo_admin_change_team_access": true,
    "username": "infraautomator",
    "visibility": "public", 
    "website": ""
    }'
org_data=$(curl -s --insecure --user $user:$pwd -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/orgs" -H "accept: application/json" -H "Content-Type: application/json" --data "${ORG_PAYLOAD}")
echo " "

CreateRepo "Infraautomator" "CICD-toolbox" "https://github.com/Devoteam/CICD-toolbox.git" "The CICD-toolbox"
CreateRepo "Infraautomator" "NetCICD" "https://github.com/Devoteam/NetCICD.git" "The NetCICD pipeline"
CreateRepo "Infraautomator" "OsCICD" "https://github.com/myref/OsCICD.git" "OsCICD"
CreateRepo "Infraautomator" "OsDeploy" "https://github.com/myref/OsDeploy.git" "OS configuration"
CreateRepo "Infraautomator" "OsTest" "https://github.com/myref/OsTest.git" "OS test"
CreateRepo "Infraautomator" "AppCICD" "https://github.com/DevoteamNL/AppCICD.git" "The AppCICD pipeline"
CreateRepo "Infraautomator" "templateApp" "https://github.com/DevoteamNL/templateApp.git" "Some Application"

CreateTeam infraautomator "gitea-CICDtoolbox-read" "The CICDtoolbox repo read role" "read" "CICD-toolbox"
CreateTeam infraautomator "gitea-CICDtoolbox-write" "The CICDtoolbox repo read-write role" "write" "CICD-toolbox"
CreateTeam infraautomator "gitea-CICDtoolbox-admin" "The CICDtoolbox repo admin role" "admin" "CICD-toolbox"

CreateTeam infraautomator "gitea-netcicd-read" "The NetCICD repo read role" "read" "NetCICD"
CreateTeam infraautomator "gitea-netcicd-write" "The NetCICD repo read-write role" "write" "NetCICD"
CreateTeam infraautomator "gitea-netcicd-admin" "The NetCICD repo admin role" "admin" "NetCICD"

CreateTeam infraautomator "gitea-OsCICD-admin" "The OsCICD repo admin role" "admin" "OsCICD"
CreateTeam infraautomator "gitea-OsCICD-write" "The OsCICD repo editor role" "write" "OsCICD"
CreateTeam infraautomator "gitea-OsCICD-read" "The OsCICD repo reader role" "read" "OsCICD"
CreateTeam infraautomator "gitea-OsDeploy-admin" "The OsDeploy repo admin role" "admin" "OsDeploy"
CreateTeam infraautomator "gitea-OsDeploy-write" "The OsDeploy repo editor role" "write" "OsDeploy"
CreateTeam infraautomator "gitea-OsDeploy-read" "The OsDeploy repo reader role" "read" "OsDeploy"
CreateTeam infraautomator "gitea-OsTest-admin" "The OsTest repo admin role" "admin" "OsTest"
CreateTeam infraautomator "gitea-OsTest-write" "The OsTest repo editor role" "write" "OsTest"
CreateTeam infraautomator "gitea-OsTest-read" "The OsTest repo reader role" "read" "OsTest"

CreateTeam infraautomator "gitea-appcicd-read" "The AppCICD repo read role" "read" "AppCICD"
CreateTeam infraautomator "gitea-appcicd-write" "The AppCICD repo read-write role" "write" "AppCICD"
CreateTeam infraautomator "gitea-appcicd-admin" "The AppCICD repo admin role" "admin" "AppCICD"
CreateTeam infraautomator "gitea-templateapp-read" "The AppCICD repo read role" "read" "templateapp"
CreateTeam infraautomator "gitea-templateapp-write" "The AppCICD repo read-write role" "write" "templateapp"
CreateTeam infraautomator "gitea-templateapp-admin" "The AppCICD repo admin role" "admin" "templateapp"

echo "****************************************************************************************************************"
echo " Adding keycloak client key to Gitea"
echo "****************************************************************************************************************"
gitea_client_id=$(grep GITEA_token install_log/keycloak_create.log | cut -d' ' -f2 | tr -d '\r' )
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "su git -c '/usr/local/bin/gitea admin auth add-oauth --name keycloak --provider openidConnect --key Gitea --secret $gitea_client_id --auto-discover-url https://keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8443/realms/cicdtoolbox/.well-known/openid-configuration --config=/data/gitea/conf/app.ini'"
# required claim name contains the claim name required to be able to use the claim, admin-group is the claim value for admin.
gitea_group_mapping=$(cat gitea/groupmapping.json | tr -d ' ' | tr -d '\n')
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "su git -c '/usr/local/bin/gitea admin auth update-oauth --id 1 --required-claim-name giteaGroups --admin-group giteaAdmin --group-claim-name giteaGroups --group-team-map $gitea_group_mapping --group-team-map-removal --skip-local-2fa'"
echo "****************************************************************************************************************"
echo " Restarting Gitea"
echo "****************************************************************************************************************"
docker restart gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}
echo " Wait until gitea is running"
until $(curl --output /dev/null --silent --head --insecure --fail https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000); do
    printf '.'
    sleep 5
done
echo " "
