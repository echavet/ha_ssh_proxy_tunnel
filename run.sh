#!/command/with-contenv bashio
set -e

# Récupération de la configuration (identique)
allowed_ips=$(bashio::config 'allowed_ips')
ssh_target=$(bashio::config 'ssh_target')
ssh_port=$(bashio::config 'ssh_port')
ssh_password=$(bashio::config 'ssh_password')
tunnel_listen_address=$(bashio::config 'tunnel_listen_address')
tunnel_listen_port=$(bashio::addon.port 80/tcp)

key_algo=$(bashio::config 'key_algo')
key_length=$(bashio::config 'key_length')
key_passphrase=$(bashio::config 'key_passphrase')

bashio::log.info "Configuration chargée : allowed_ips=${allowed_ips}, ssh_target=${ssh_target}, ssh_port=${ssh_port}, tunnel_listen_address=${tunnel_listen_address}, tunnel_listen_port=${tunnel_listen_port}"
bashio::log.info "Algorithme de clé : ${key_algo}, longueur : ${key_length}"

# Préparer le dossier persistant pour la clé
mkdir -p /data/ssh_keys

# Génération de la clé SSH (fichier /data/ssh_keys/id_tunnel) si elle n'existe pas
if [ ! -f /data/ssh_keys/id_tunnel ]; then
    bashio::log.notice "Clé SSH introuvée, génération d'une nouvelle paire..."
    case "$key_algo" in
      rsa|dsa|ecdsa)
          keygen_options="-b ${key_length}"
          ;;
      ed25519|ed25519-sk|ecdsa-sk)
          keygen_options=""
          ;;
      *)
          bashio::log.fatal "Algorithme non supporté: ${key_algo}"
          exit 1
          ;;
    esac
    ssh-keygen -t "$key_algo" ${keygen_options} -f /data/ssh_keys/id_tunnel -N "${key_passphrase}" \
        || { bashio::log.fatal "Échec de la génération de la clé SSH"; exit 1; }
    bashio::log.info "Clé publique générée, copiez-la sur le serveur distant :"
    bashio::log.info "$(cat /data/ssh_keys/id_tunnel.pub)"
fi

# Si la clé est protégée par une passphrase, la déverrouiller avec ssh-agent
if [ -n "${key_passphrase}" ]; then
    bashio::log.info "Déverrouillage de la clé avec ssh-agent..."
    eval "$(ssh-agent -s)"
    cat <<EOF >/tmp/askpass.sh
#!/bin/bash
echo "${key_passphrase}"
EOF
    chmod +x /tmp/askpass.sh
    export SSH_ASKPASS=/tmp/askpass.sh
    export DISPLAY=:0
    ssh-add /data/ssh_keys/id_tunnel || bashio::log.fatal "Échec de l'ajout de la clé dans ssh-agent"
fi

# Options SSH (explication ci-dessous)
SSH_OPTIONS="-o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Appliquer les règles iptables
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
IFS=',' read -ra IPS <<< "${allowed_ips}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "${ip}" -j ACCEPT
done
iptables -A INPUT -p tcp --dport "${tunnel_listen_port}" -j DROP

# Prioriser l'usage de la clé
if [ -f /data/ssh_keys/id_tunnel ]; then
    bashio::log.info "Lancement du tunnel SSH avec authentification par clé RSA..."
    exec ssh -ND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" -i /data/ssh_keys/id_tunnel ${SSH_OPTIONS}
elif bashio::config.has_value 'ssh_password'; then
    SSHPASS="sshpass -p '$(bashio::config 'ssh_password')'"
    bashio::log.info "Lancement du tunnel SSH avec authentification par mot de passe..."
    exec ${SSHPASS} ssh -ND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    bashio::log.fatal "Aucune méthode d'authentification disponible."
    exit 1
fi
