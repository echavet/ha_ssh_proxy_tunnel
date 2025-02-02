#!/bin/bash
# run.sh
set -e

echo "Port du tunnel utilisé: ${CONFIG_TUNNEL_LISTEN_PORT}"
echo "Tunnel listen address: ${CONFIG_TUNNEL_LISTEN_ADDRESS}"
echo "IPs autorisées : ${CONFIG_ALLOWED_IPS}"

# Appliquer les règles iptables pour limiter l'accès au tunnel
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

IFS=',' read -ra IPS <<< "${CONFIG_ALLOWED_IPS}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "$ip" -j ACCEPT
done
iptables -A INPUT -p tcp --dport "${CONFIG_TUNNEL_LISTEN_PORT}" -j DROP

# Options SSH de base
SSH_OPTIONS="-o ExitOnForwardFailure=yes"

# Authentification par clé RSA si fournie
if [ "${CONFIG_AUTHORIZED_KEYS}" != "[]" ] && [ -n "${CONFIG_AUTHORIZED_KEYS}" ]; then
    mkdir -p /root/.ssh
    echo "${CONFIG_AUTHORIZED_KEYS}" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    SSH_OPTIONS="${SSH_OPTIONS} -i /root/.ssh/id_rsa"
elif [ -n "${CONFIG_SSH_PASSWORD}" ]; then
    # Préparer sshpass pour le mot de passe
    SSHPASS="sshpass -p '${CONFIG_SSH_PASSWORD}'"
else
    echo "Erreur : fournir un mot de passe SSH ou une clé RSA."
    exit 1
fi

# Lancer le tunnel SSH en utilisant sshpass si le mot de passe est renseigné
if [ -n "${CONFIG_SSH_PASSWORD}" ] && { [ "${CONFIG_AUTHORIZED_KEYS}" == "[]" ] || [ -z "${CONFIG_AUTHORIZED_KEYS}" ]; }; then
    exec ${SSHPASS} ssh -fND "${CONFIG_TUNNEL_LISTEN_ADDRESS}:${CONFIG_TUNNEL_LISTEN_PORT}" "${CONFIG_SSH_TARGET}" -p "${CONFIG_SSH_PORT}" ${SSH_OPTIONS}
else
    exec ssh -fND "${CONFIG_TUNNEL_LISTEN_ADDRESS}:${CONFIG_TUNNEL_LISTEN_PORT}" "${CONFIG_SSH_TARGET}" -p "${CONFIG_SSH_PORT}" ${SSH_OPTIONS}
fi
