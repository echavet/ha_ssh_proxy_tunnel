#!/command/with-contenv bashio
set -e

# Récupération des options via bashio
allowed_ips=$(bashio::config.get "allowed_ips")
ssh_target=$(bashio::config.get "ssh_target")
ssh_port=$(bashio::config.get "ssh_port")
ssh_password=$(bashio::config.get "ssh_password")
authorized_keys=$(bashio::config.get "authorized_keys")
tunnel_listen_address=$(bashio::config.get "tunnel_listen_address")
tunnel_listen_port=$(bashio::config.get "tunnel_listen_port")

bashio::log.info "Configuration chargée : allowed_ips=${allowed_ips}, ssh_target=${ssh_target}, ssh_port=${ssh_port}, tunnel_listen_address=${tunnel_listen_address}, tunnel_listen_port=${tunnel_listen_port}"

# Appliquer les règles iptables
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

IFS=',' read -ra IPS <<< "${allowed_ips}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "$ip" -j ACCEPT
done
iptables -A INPUT -p tcp --dport "${tunnel_listen_port}" -j DROP

SSH_OPTIONS="-o ExitOnForwardFailure=yes"

# Authentification par clé RSA si fournie
if bashio::var.has_value "${authorized_keys}" && [ "${authorized_keys}" != "[]" ]; then
    mkdir -p /root/.ssh
    echo "${authorized_keys}" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    SSH_OPTIONS="${SSH_OPTIONS} -i /root/.ssh/id_rsa"
elif bashio::var.has_value "${ssh_password}"; then
    SSHPASS="sshpass -p '${ssh_password}'"
else
    bashio::log.error "Aucune méthode d'authentification fournie (clé RSA ou mot de passe)."
    exit 1
fi

# Lancer le tunnel SSH
if bashio::var.has_value "${ssh_password}" && ! bashio::var.has_value "${authorized_keys}"; then
    exec ${SSHPASS} ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    exec ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
fi
