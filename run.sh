#!/command/with-contenv bashio
set -e

# Récupération de la configuration
allowed_ips=$(bashio::config 'allowed_ips')
ssh_target=$(bashio::config 'ssh_target')
ssh_port=$(bashio::config 'ssh_port')
ssh_password=$(bashio::config 'ssh_password')
tunnel_listen_address=$(bashio::config 'tunnel_listen_address')
tunnel_listen_port=$(bashio::config 'tunnel_listen_port')
key_algo=$(bashio::config 'key_algo')
key_length=$(bashio::config 'key_length')
key_passphrase=$(bashio::config 'key_passphrase')

bashio::log.info "Configuration chargée : allowed_ips=${allowed_ips}, ssh_target=${ssh_target}, ssh_port=${ssh_port}, tunnel_listen_address=${tunnel_listen_address}, tunnel_listen_port=${tunnel_listen_port}"
bashio::log.info "Algorithme de clé : ${key_algo}, longueur : ${key_length}"

# Préparer le dossier .ssh
mkdir -p /root/.ssh

# Génération de la clé SSH (fichier /root/.ssh/id_tunnel) si elle n'existe pas
if [ ! -f /root/.ssh/id_tunnel ]; then
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
    ssh-keygen -t "$key_algo" ${keygen_options} -f /root/.ssh/id_tunnel -N "${key_passphrase}" \
        || { bashio::log.fatal "Échec de la génération de la clé SSH"; exit 1; }
    bashio::log.info "Clé publique générée, copiez-la sur le serveur distant :"
    bashio::log.info "$(cat /root/.ssh/id_tunnel.pub)"
fi

# Si la clé est protégée par une passphrase, déverrouille-la via ssh-agent
if [ -n "${key_passphrase}" ]; then
    bashio::log.info "Ajout de la clé dans ssh-agent..."
    eval "$(ssh-agent -s)"
    # Créer un script temporaire pour SSH_ASKPASS qui retourne la passphrase
    cat <<EOF >/tmp/askpass.sh
#!/bin/bash
echo "${key_passphrase}"
EOF
    chmod +x /tmp/askpass.sh
    export SSH_ASKPASS=/tmp/askpass.sh
    export DISPLAY=:0
    # ssh-add utilisera SSH_ASKPASS pour fournir la passphrase
    ssh-add /root/.ssh/id_tunnel || bashio::log.fatal "Échec de l'ajout de la clé dans ssh-agent"
fi

# Options SSH de base (désactivation de la vérification de la clé d'hôte)
SSH_OPTIONS="-o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Appliquer les règles iptables pour limiter l'accès au tunnel
iptables -F
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
IFS=',' read -ra IPS <<< "${allowed_ips}"
for ip in "${IPS[@]}"; do
    iptables -A INPUT -s "${ip}" -j ACCEPT
done
iptables -A INPUT -p tcp --dport "${tunnel_listen_port}" -j DROP

# Lancer le tunnel SSH
if bashio::config.has_value 'ssh_password'; then
    SSHPASS="sshpass -p '$(bashio::config 'ssh_password')'"
    bashio::log.info "Lancement du tunnel SSH avec authentification par mot de passe..."
    exec ${SSHPASS} ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    bashio::log.info "Lancement du tunnel SSH avec authentification par clé RSA..."
    exec ssh -fND "${tunnel_listen_address}:${tunnel_listen_port}" "${ssh_target}" -p "${ssh_port}" -i /root/.ssh/id_tunnel ${SSH_OPTIONS}
fi
