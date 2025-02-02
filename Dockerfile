ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV S6_SERVICES_GRACETIME=220000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Installer openssh-client, iptables, bash et sshpass pour la gestion du mot de passe
RUN apk add --no-cache openssh-client iptables bash sshpass

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
