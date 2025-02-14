# pulling offical image
FROM gitea/gitea:1

#RUN mkdir /data/gitea/templates/
COPY home.tmpl /data/gitea/templates/home.tmpl

ARG DOMAIN_NAME_SL
ARG DOMAIN_NAME_TL
COPY gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem /data/gitea/gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem
RUN mkdir /home/git
RUN chown git:git /home/git
COPY --chmod=0600 --chown=git:git gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.pem /home/git/.postgresql/postgresql.key

COPY gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt /data/gitea/gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt
COPY --chmod=0644 --chown=git:git gitea.tooling.${DOMAIN_NAME_SL}.${DOMAIN_NAME_TL}.crt /home/git/.postgresql/postgresql.crt

COPY ca.crt /home/git/.postgresql/root.crt
USER root
# COPY COMPANY_ROOT_CA.crt /usr/local/share/ca-certificates
# RUN update-ca-certificates
# user 1000:1000