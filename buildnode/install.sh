#!/bin/bash 

create_runner_node() {
    sleep 5
    echo "****************************************************************************************************************"
    echo " Creating Gitea runner for ${1} with name ${4} and sequence number ${3}"
    echo "****************************************************************************************************************"
    robot --variable environment:$1 --variable VALID_PASSWORD:$2 -d install/log/ -o .30_build-$1_runner_create.xml -l 30_build-$1_runner_create_log.html -r 30_build-$1_runner_create_report.html buildnode/runnertoken.robot
    export RUNNER_TOKEN=$(cat buildnode/${1}_runner_token)
    echo "****************************************************************************************************************"
    echo " Adding buildnode_$1 to Keycloak"
    echo "****************************************************************************************************************"
    docker cp buildnode/add_buildnode_to_realm.sh keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:/opt/keycloak/bin/add_build_$1_to_realm.sh
    docker exec -it keycloak.services.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} sh -c "/opt/keycloak/bin/add_buildnode_to_realm.sh ${local_admin_user} ${local_admin_password} ${1} ${4}" | tee install/log/keycloak_pulp_create.log
    echo "****************************************************************************************************************"
    echo " Starting buildnode"
    echo "****************************************************************************************************************"
    docker compose --project-name cicd-toolbox up -d --build --no-deps --force-recreate build-$1
    docker exec --user root -it build-$1.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL} /bin/bash -c "source /etc/rc.local"
    echo "****************************************************************************************************************"
    echo " Validating Gitea runner for ${1} with name ${4} and sequence number ${3}"
    echo "****************************************************************************************************************"
    robot --variable ENVIRONMENT:$1 --variable VALID_PASSWORD:$2 --variable SEQ_NR:$3 --variable NAME:$4 -d install/log/ -o 31_build-$1_runner_test.xml -l 31_build-$1_runner_test_log.html -r 31_build-$1_runner_test_report.html ./buildnode/runner_validate.robot
}

echo "****************************************************************************************************************"
echo " Ensure reachability of build-dev"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "build-dev" /etc/hosts; then
    sudo sed -i "/build-dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.12.2   build-dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   build-dev.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Ensure reachability of build-test"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "build-test" /etc/hosts; then
    sudo sed -i "/build-test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.12.3   build-test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   build-test.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Ensure reachability of build-acc"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "build-acc" /etc/hosts; then
    sudo sed -i "/build-acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.12.4   build-acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   build-acc.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Ensure reachability of build-prod"
echo "****************************************************************************************************************"
sudo chmod o+w /etc/hosts
if grep -q "build-prod" /etc/hosts; then
    sudo sed -i "/build-prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}/d" /etc/hosts
fi
echo "172.16.12.5   build-prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> /etc/hosts
if [ "$install_mode" = "vm" ]; then
    echo $host_ip"   build-prod.delivery.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}" >> hosts_additions.txt
fi
sudo chmod o-w /etc/hosts
echo "****************************************************************************************************************"
echo " Ensure presence of Gitea runner software"
echo "****************************************************************************************************************"
if [ -f "buildnode/act_runner-0.2.11-linux-amd64" ]; then
    echo " Gitea runner software exists"
else
    echo " Get Gitea runner software"
    wget --directory-prefix=buildnode https://dl.gitea.com/act_runner/0.2.11/act_runner-0.2.11-linux-amd64
fi
chmod +x  buildnode/act_runner-0.2.11-linux-amd64
echo "****************************************************************************************************************"
echo " Starting buildnodes"
echo "****************************************************************************************************************"
create_runner_node "dev" ${default_user_password} 1 "Dev"
create_runner_node "test" ${default_user_password} 2 "Test"
create_runner_node "acc" ${default_user_password} 3 "Acc"
create_runner_node "prod" ${default_user_password} 4 "Prod"