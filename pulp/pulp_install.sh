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
    echo " Creating repository $1 with remote $2, distrbution name $3 and remote options $4[@]"
    echo "****************************************************************************************************************"
    pulp --no-verify-ssl deb remote create --name=${1} ${4[@]}
    pulp --no-verify-ssl deb repository create --name $1 --remote=${2}
    pulp --no-verify-ssl deb repository sync --name=${1}
    pulp --no-verify-ssl deb publication create --repository=${1}
    pulp --no-verify-ssl deb distribution create --name $1 --base-path $1 --repository $1
    pulp --no-verify-ssl deb repository update --name $1 --autopublish
    pulp --no-verify-ssl deb distribution show --name $1
}

echo "****************************************************************************************************************"
echo " Starting Pulp"
echo "****************************************************************************************************************"
docker compose --project-name cicd-toolbox up -d --build --no-deps pulp.tooling.provider.test
let t=0
until $(curl --output /dev/null --insecure --silent --head --fail https://pulp.tooling.provider.test/pulp/api/v3/status/); do
    spin
done
endspin
echo " " 
echo "****************************************************************************************************************"
echo " Setting pulp admin password"
echo "****************************************************************************************************************"
docker exec -it pulp.tooling.provider.test sh -c "pulpcore-manager reset-admin-password --password $1"
pulp --no-verify-ssl config create --username admin --base-url https://pulp.tooling.provider.test --password $1
echo "****************************************************************************************************************"
echo " Creating repository and distribution"
echo "****************************************************************************************************************"
create_file_repo "file" "testreports-dev" "dev-reports"
create_file_repo "file" "testreports-test" "test-reports"
create_file_repo "file" "testreports-acc" "acc-reports"
create_file_repo "file" "testreports-prod" "prod-reports"
create_deb_repo "curated" "https://deb.debian.org/debian" "my-deb" "--download-concurrency 4"
