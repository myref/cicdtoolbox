#!/bin/bash

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
    curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/repos/migrate" -H  "accept: application/json" -H  "Content-Type: application/json" -d "${repo_payload}"
    echo " "
    echo "****************************************************************************************************************"
    echo " Creating webhook for the ${2} repo"
    echo "****************************************************************************************************************"
    local webhook_payload='{
        "active": true,
        "branch_filter": "*",
        "config": {
            "content_type": "json",
            "url": "https://jenkins.tooling.'${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}':8084/gitea-webhook/post"
            },
        "events": [ "push" ],
        "type": "gitea"
        }'
    curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/repos/${1}/${2}/hooks" -H  "accept: application/json" -H  "Content-Type: application/json" -d "${webhook_payload}"
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
    local team_data=$(curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/orgs/${1}/teams" -H "accept: application/json" -H "Content-Type: application/json" -d "${team_payload}")
    local team_id=$( echo $team_data | awk -F',' '{print $(1)}' | awk -F':' '{print $2}' )
    echo " "
    echo "****************************************************************************************************************"
    echo " Adding ${5} repo to ${2} team in Gitea "
    echo "****************************************************************************************************************"
    curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X PUT "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/teams/${team_id}/repos/${ORG_NAME}/${5}" -H  "accept: application/json"
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
echo " Ensure reachability of Gitea"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "gitea" /etc/hosts; then
    sudo sed -i "/gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.11.3   gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Saving gitea certificates"
echo "****************************************************************************************************************"
cp vault/certs/gitea* gitea/
echo "****************************************************************************************************************"
echo " Substituting org_name in groupmapping.json"
echo "****************************************************************************************************************"
cp gitea/groupmapping.json.org gitea/groupmapping.json
sed -i "s/org_name/${ORG_NAME}/" gitea/groupmapping.json
echo "****************************************************************************************************************"
echo " Add Gitea to keycloak"
echo "****************************************************************************************************************"
docker cp gitea/add_gitea_to_realm.sh keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/keycloak/bin/add_gitea_to_realm.sh | tee install/log/keycloak_gitea_create.log
docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/add_gitea_to_realm.sh ${local_admin_user} ${local_admin_password}" | tee install/log/keycloak_gitea_create.log
echo " "
echo "****************************************************************************************************************"
echo " Starting Gitea"
echo "****************************************************************************************************************"
DOCKER_BUILDKIT=1 docker compose --project-name cicd-toolbox up -d --build --no-deps gitea
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
echo " Create local gituser (admin role: ${local_admin_user})"
echo "****************************************************************************************************************"
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "su git -c '/usr/local/bin/gitea admin user create --username ${local_admin_user} --password ${local_admin_password} --admin --email gitea-local-admin@tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}'"
echo " "
echo "****************************************************************************************************************"
echo " Creating ${ORG_NAME}s organization in Gitea "
echo "****************************************************************************************************************"
ORG_PAYLOAD="{ 
    \"description\": \"Automation transformation team\", 
    \"full_name\": \"${ORG_NAME}\", 
    \"location\": \"Github\",
    \"repo_admin_change_team_access\": true,
    \"username\": \"${ORG_NAME}\",
    \"visibility\": \"public\", 
    \"website\": \"\"
    }"
org_data=$(curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X POST "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/orgs" -H "accept: application/json" -H "Content-Type: application/json" --data "${ORG_PAYLOAD}")
echo $org_data

CreateRepo "${ORG_NAME}" "CICD-toolbox" "https://github.com/Devoteam/CICD-toolbox.git" "The CICD-toolbox"
CreateRepo "${ORG_NAME}" "NetCICD" "https://github.com/Devoteam/NetCICD.git" "The NetCICD pipeline"
CreateRepo "${ORG_NAME}" "OsCICD" "https://github.com/myref/OsCICD.git" "OsCICD"
CreateRepo "${ORG_NAME}" "OsTest" "https://github.com/myref/OsTest.git" "OS test"
CreateRepo "${ORG_NAME}" "AppCICD" "https://github.com/DevoteamNL/AppCICD.git" "The AppCICD pipeline"
CreateRepo "${ORG_NAME}" "AppTest" "https://github.com/myref/OsTest.git" "Application testing"
CreateRepo "${ORG_NAME}" "templateApp" "https://github.com/DevoteamNL/templateApp.git" "Some Application"

CreateTeam ${ORG_NAME} "gitea-cicdtoolbox-read" "The CICDtoolbox repo read role" "read" "CICD-toolbox"
CreateTeam ${ORG_NAME} "gitea-cicdtoolbox-write" "The CICDtoolbox repo read-write role" "write" "CICD-toolbox"
CreateTeam ${ORG_NAME} "gitea-cicdtoolbox-admin" "The CICDtoolbox repo admin role" "admin" "CICD-toolbox"

CreateTeam ${ORG_NAME} "gitea-netcicd-read" "The NetCICD repo read role" "read" "NetCICD"
CreateTeam ${ORG_NAME} "gitea-netcicd-write" "The NetCICD repo read-write role" "write" "NetCICD"
CreateTeam ${ORG_NAME} "gitea-netcicd-admin" "The NetCICD repo admin role" "admin" "NetCICD"

CreateTeam ${ORG_NAME} "gitea-oscicd-admin" "The OsCICD repo admin role" "admin" "OsCICD"
CreateTeam ${ORG_NAME} "gitea-oscicd-write" "The OsCICD repo editor role" "write" "OsCICD"
CreateTeam ${ORG_NAME} "gitea-oscicd-read" "The OsCICD repo reader role" "read" "OsCICD"

CreateTeam ${ORG_NAME} "gitea-ostest-admin" "The OsTest repo admin role" "admin" "OsTest"
CreateTeam ${ORG_NAME} "gitea-ostest-write" "The OsTest repo editor role" "write" "OsTest"
CreateTeam ${ORG_NAME} "gitea-ostest-read" "The OsTest repo reader role" "read" "OsTest"

CreateTeam ${ORG_NAME} "gitea-appcicd-read" "The AppCICD repo read role" "read" "AppCICD"
CreateTeam ${ORG_NAME} "gitea-appcicd-write" "The AppCICD repo read-write role" "write" "AppCICD"
CreateTeam ${ORG_NAME} "gitea-appcicd-admin" "The AppCICD repo admin role" "admin" "AppCICD"
CreateTeam ${ORG_NAME} "gitea-templateapp-read" "The AppCICD repo read role" "read" "templateapp"
CreateTeam ${ORG_NAME} "gitea-templateapp-write" "The AppCICD repo read-write role" "write" "templateapp"
CreateTeam ${ORG_NAME} "gitea-templateapp-admin" "The AppCICD repo admin role" "admin" "templateapp"

echo "****************************************************************************************************************"
echo " Adding keycloak client key to Gitea"
echo "****************************************************************************************************************"
gitea_client_id=$(grep GITEA_token install/log/keycloak_gitea_create.log | cut -d' ' -f2 | tr -d '\r' )
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
