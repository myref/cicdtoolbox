FROM jenkins/jenkins:lts-jdk17

ENV JAVA_OPTS "-Djenkins.install.runSetupWizard=false ${JAVA_OPTS:-}"
ENV CASC_JENKINS_CONFIG /var/jenkins_conf/casc.yaml

ARG ORG_NAME

COPY keystore/jenkins.jks /opt/java/openjdk/lib/security/jenkins.jks
ENV JENKINS_OPTS --httpPort=-1  --httpsPort=8084 --httpsKeyStore="/opt/java/openjdk/lib/security/jenkins.jks" --httpsKeyStorePassword=changeit

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

COPY casc.yaml /var/jenkins_conf/casc.yaml
COPY ${ORG_NAME}/ /var/jenkins_home/jobs/${ORG_NAME}/

ARG JAVA_OPTS
