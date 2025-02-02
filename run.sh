#!/command/with-contenv bashio
set -e

# Récupérer les options de configuration
allowed_ips=$(bashio::config 'allowed_ips')
ssh_target=$(bashio::config 'ssh_target')
ssh_port=$(bashio::config 'ssh_port')
ssh_password=$(bashio::config 'ssh_password')
authorized_keys=$(bashio::config 'authorized_keys')
tunnel_listen_address=$(bashio::config 'tunnel_listen_address')
tunnel_listen_port=$(bashio::config 'tunnel_listen_port')

bashio::log.info "Configuration chargée : allowed_ips=${allowed_ips}, ssh_target=${ssh_target}, ssh_port=${ssh_port}, tunnel_listen_address=${tunnel_listen_address}, tunnel_listen_port=${tunnel_listen_port}"

# Appliquer les règles iptables pour limiter l'accès au tunnel
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Pour chaque IP autorisée (séparées par des virgules)
IFS=',' read -ra IPS <<< "${allowed_ips}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "${ip}" -j ACCEPT
done

# Bloquer l'accès au port du tunnel pour les autres
iptables -A INPUT -p tcp --dport "${tunnel_listen_port}" -j DROP

# Options SSH de base, avec désactivation de la vérification de la clé d'hôte
SSH_OPTIONS="-o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Authentification :
# Si une clé RSA est fournie (non vide), on l'utilise.
if bashio::config.has_value 'authorized_keys'; then
    # authorized_keys est défini dans le schéma comme une liste.
    # On la transforme en une chaîne (si plusieurs clés sont renseignées, seule la première sera utilisée pour l'authentification client).
    keys=$(bashio::config 'authorized_keys')
    if [ -n "${keys}" ] && [ "${keys}" != "[]" ]; then
        mkdir -p /root/.ssh
        # On enregistre la clé dans le fichier id_rsa
        echo "${keys}" > /root/.ssh/id_rsa
        chmod 600 /root/.ssh/id_rsa
        SSH_OPTIONS="${SSH_OPTIONS} -i /root/.ssh/id_rsa"
    fi
fi

# Si aucune clé n'est fournie et qu'un mot de passe est renseigné, on prépare sshpass
if ! bashio::config.has_value 'authorized_keys' && bashio::config.has_value 'ssh_password'; then
    SSHPASS="sshpass -p '$(bashio::config 'ssh_password')'"
fi

# Lancer le tunnel SSH en arrière-plan (mode proxy SOCKS)
if bashio::config.has_value 'ssh_password' && ! bashio::config.has_value 'authorized_keys'; then
    bashio::log.info "Lancement du tunnel SSH avec authentification par mot de passe..."
    exec ${SSHPASS} ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    bashio::log.info "Lancement du tunnel SSH avec authentification par clé RSA..."
    exec ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
fi
