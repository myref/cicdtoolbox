#!/bin/sh
service docker restart

if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
	# generate fresh rsa key
	/usr/bin/ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi
if [ ! -f "/etc/ssh/ssh_host_dsa_key" ]; then
	# generate fresh dsa key
	/usr/bin/ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi

echo "192.168.122.16 kvmhost" >> /etc/hosts

# prepare run dir
if [ ! -d "/var/run/sshd" ]; then
  mkdir -p /var/run/sshd
fi

cd /home/jenkins

if [ ! -d "/home/jenkins/.ssh" ]; then
	mkdir /home/jenkins/.ssh
fi

if [ ! -f "/home/jenkins/.ssh/id_rsa" ]; then
	#generate ID
	ssh-keygen -t rsa -N "" -f /home/jenkins/.ssh/id_rsa -C "jenkins-user"
fi

chown jenkins:jenkins /home/jenkins/.ssh/id*

# Manual: ssh-copy-id -i /home/jenkins/.ssh/id_rsa.pub kvmuser@kvmhost

echo "-----------------------------------------------------"
echo "Build environment: ${BUILD_ENVIRONMENT}"
echo " "
RUNNER_TOKEN=$(cat git-token.txt)
echo "Runner token: ${RUNNER_TOKEN}"
echo "-----------------------------------------------------"
cat secret-file.txt

/home/jenkins/act_runner register --instance https://gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:3000 --name $BUILD_ENVIRONMENT --token $RUNNER_TOKEN --no-interactive
sleep 1
/home/jenkins/act_runner daemon >/dev/null 2>&1 &
sleep 1
su jenkins -c 'java -jar agent.jar -url "https://jenkins.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}:8084/" -secret @secret-file.txt -name $BUILD_ENVIRONMENT -webSocket -workDir "/home/jenkins" &'

exec "$@"
