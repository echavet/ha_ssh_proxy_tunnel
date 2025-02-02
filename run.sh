#!/command/with-contenv bashio
set -e

# Récupérer la configuration via bashio
allowed_ips=$(bashio::config 'allowed_ips')
ssh_target=$(bashio::config 'ssh_target')
ssh_port=$(bashio::config 'ssh_port')
ssh_password=$(bashio::config 'ssh_password')
rsa_key=$(bashio::config 'authorized_key')
tunnel_listen_address=$(bashio::config 'tunnel_listen_address')
tunnel_listen_port=$(bashio::config 'tunnel_listen_port')

bashio::log.info "Configuration chargée : allowed_ips=${allowed_ips}, ssh_target=${ssh_target}, ssh_port=${ssh_port}, tunnel_listen_address=${tunnel_listen_address}, tunnel_listen_port=${tunnel_listen_port}"

# Appliquer les règles iptables
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

IFS=',' read -ra IPS <<< "${allowed_ips}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "${ip}" -j ACCEPT
done

iptables -A INPUT -p tcp --dport "${tunnel_listen_port}" -j DROP

# Options SSH avec désactivation de la vérification d'hôte
SSH_OPTIONS="-o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Authentification
if bashio::var.has_value "${rsa_key}"; then
    mkdir -p /root/.ssh
    echo "${rsa_key}" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    SSH_OPTIONS="${SSH_OPTIONS} -i /root/.ssh/id_rsa"
elif bashio::config.has_value 'ssh_password'; then
    SSHPASS="sshpass -p '$(bashio::config 'ssh_password')'"
else
    bashio::log.error "Aucune méthode d'authentification fournie (clé RSA ou mot de passe)."
    exit 1
fi

# Lancer le tunnel SSH
if bashio::config.has_value 'ssh_password' && ! bashio::var.has_value "${rsa_key}"; then
    bashio::log.info "Lancement du tunnel SSH avec authentification par mot de passe..."
    exec ${SSHPASS} ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    bashio::log.info "Lancement du tunnel SSH avec authentification par clé RSA..."
    exec ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
fi
