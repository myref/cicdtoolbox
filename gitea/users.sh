#!/bin/bash +x

echo "****************************************************************************************************************"
echo " Adding users to Gitea "
echo "****************************************************************************************************************"
docker exec -it gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "su git -c '/usr/local/bin/gitea admin user create --username Jenkins --password '${default_user_password}' --email jenkins@tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}'"
curl -s --insecure --user ${local_admin_user}:${local_admin_password} -X 'PUT' "https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000/api/v1/teams/1/members/Jenkins"  -H 'accept: application/json'
