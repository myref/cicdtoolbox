FROM registry.access.redhat.com/ubi9 AS ubi-micro-build
COPY ca.crt /etc/pki/ca-trust/source/anchors/mycertificate.crt
RUN update-ca-trust

FROM quay.io/keycloak/keycloak:latest
COPY --from=ubi-micro-build /etc/pki /etc/pki
COPY create-realm.sh /opt/keycloak/bin/create-realm.sh

EXPOSE 8080
EXPOSE 8443
EXPOSE 8190
