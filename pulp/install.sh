#!/bin/bash

# Started with sh -c "pulp_install.sh ${pulp_pass}"

sp="/-\|"
sc=0
spin() {
   printf -- "${sp:sc++:1}  ( ${t} sec.) \r"
   ((sc==${#sp})) && sc=0
   sleep 1
   let t+=1
}

endspin() {
   printf "\r%s\n" "$@"
}

function create_file_repo() {
    echo "****************************************************************************************************************"
    echo " Creating repository $2 with distrbution name $3"
    echo "****************************************************************************************************************"
    pulp --no-verify-ssl $1 repository create --name $2
    pulp --no-verify-ssl $1 distribution create --name $2 --base-path $3 --repository $2
    pulp --no-verify-ssl $1 repository update --name $2 --autopublish
    pulp --no-verify-ssl $1 distribution show --name $2
}

function create_deb_repo() {
    echo "****************************************************************************************************************"
    echo " Creating repository $1 with remote $2, distribution name $3 and remote options $4"
    echo "****************************************************************************************************************"
    NAME=$1
    REMOTE_OPTIONS=(
     --url=$2
     --distribution=$3
     --component=nginx
     --architecture=amd64
    )
    pulp --no-verify-ssl deb remote create --name=${NAME} ${REMOTE_OPTIONS[@]}
    pulp --no-verify-ssl deb repository create --name=${NAME} --remote=${NAME}
    pulp --no-verify-ssl deb repository sync --name=${NAME}
    pulp --no-verify-ssl deb publication create --repository=${NAME}
    pulp --no-verify-ssl deb distribution create --name ${NAME} --base-path ${NAME} --repository ${NAME}
    pulp --no-verify-ssl deb repository update --name ${NAME} --autopublish
    pulp --no-verify-ssl deb distribution show --name ${NAME}
}
echo "****************************************************************************************************************"
echo " Ensure reachability of Pulp"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "pulp" /etc/hosts; then
    sudo sed -i "/pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.11.10   pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Starting Pulp"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps pulp
let t=0
until $(curl --output /dev/null --insecure --silent --head --fail https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/pulp/api/v3/status/); do
    spin
done
endspin
echo " " 
echo "****************************************************************************************************************"
echo " Setting pulp admin password"
echo "****************************************************************************************************************"
docker exec -it pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "pulpcore-manager reset-admin-password --password ${local_admin_password}"
pulp --no-verify-ssl config create --username admin --base-url https://pulp.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} --password ${local_admin_password}
echo "****************************************************************************************************************"
echo " Creating repository and distribution"
echo "****************************************************************************************************************"
create_file_repo "file" "toolbox_install" "install/logs"
create_file_repo "file" "testreports-dev" "dev-reports"
create_file_repo "file" "testreports-test" "test-reports"
create_file_repo "file" "testreports-acc" "acc-reports"
create_file_repo "file" "testreports-prod" "prod-reports"
create_deb_repo "quickstart-nginx-bookworm-amd64" "http://nginx.org/packages/debian/" "bookworm" "--download-concurrency 4"
