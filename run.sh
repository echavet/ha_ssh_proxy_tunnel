#!/command/with-contenv bashio
set -e

# Récupération de la configuration via bashio
ssh_debug=$(bashio::config 'ssh_debug')
iptable_debug=$(bashio::config 'iptable_debug')
allowed_ips=$(bashio::config 'allowed_ips')
allowed_macs=$(bashio::config 'allowed_macs')
ssh_target=$(bashio::config 'ssh_target')
ssh_port=$(bashio::config 'ssh_port')
ssh_password=$(bashio::config 'ssh_password')
tunnel_listen_address=$(bashio::config 'tunnel_listen_address')
# Récupération du port via la section ports du config.yaml (par exemple, 80/tcp: 3001)
tunnel_listen_port=$(bashio::addon.port "80/tcp")
key_algo=$(bashio::config 'key_algo')
key_length=$(bashio::config 'key_length')
key_passphrase=$(bashio::config 'key_passphrase')

# Récupère le niveau de log depuis la configuration (log_level doit être défini dans config.yaml)
log_level=$(bashio::config 'log_level')

# Définit le niveau de log en fonction du paramètre (par exemple "debug", "info", "warning", etc.)
bashio::log.level "$log_level"


bashio::log.info "Tunnel SSH: destination ${ssh_target}:${ssh_port}"
bashio::log.info "Tunnel écoute sur ${tunnel_listen_address}:80, mappé en externe sur le port ${tunnel_listen_port}"



# Affichage de la configuration dans les logs pour vérification
bashio::log.info "Configuration chargée :"
#bashio::log.info "  allowed_ips           = ${allowed_ips}"
#bashio::log.info "  allowed_macs          = ${allowed_macs}"
bashio::log.info "  ssh_target            = ${ssh_target}"
bashio::log.info "  ssh_port              = ${ssh_port}"
bashio::log.info "  tunnel_listen_address = ${tunnel_listen_address}"
bashio::log.info "  tunnel_listen_port    = ${tunnel_listen_port}"
bashio::log.info "  key_algo              = ${key_algo}"
bashio::log.info "  key_length            = ${key_length}"

###############################################################################
# Préparation de la clé SSH
###############################################################################

# On utilise /data/ssh_keys pour stocker la clé de manière persistante (ce dossier doit être mappé en volume)
mkdir -p /data/ssh_keys

# Si la clé n'existe pas, on la génère avec les paramètres configurés
if [ ! -f /data/ssh_keys/id_tunnel ]; then
    bashio::log.notice "Clé SSH introuvée, génération d'une nouvelle paire..."
    # Pour rsa, dsa, ou ecdsa, on ajoute l'option -b pour spécifier la longueur
    case "$key_algo" in
      rsa|dsa|ecdsa)
          keygen_options="-b ${key_length}"
          ;;
      # Pour ed25519 et ses variantes, la longueur est fixe
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
    # Création d'un script temporaire pour fournir automatiquement la passphrase via SSH_ASKPASS
    cat <<EOF >/tmp/askpass.sh
#!/bin/bash
echo "${key_passphrase}"
EOF
    chmod +x /tmp/askpass.sh
    export SSH_ASKPASS=/tmp/askpass.sh
    # SSH_ASKPASS nécessite la variable DISPLAY ; ici on la définit à :0
    export DISPLAY=:0
    # Ajout de la clé dans l'agent
    ssh-add /data/ssh_keys/id_tunnel || bashio::log.fatal "Échec de l'ajout de la clé dans ssh-agent"
fi

###############################################################################
# Définition des options SSH pour diagnostiquer les connexions
###############################################################################

# Définir la variable verbose selon ssh_debug
if bashio::config.true 'ssh_debug'; then
    verbose="-vvv"
else
    verbose=""
fi


# SSH_OPTIONS contient :
# - ExitOnForwardFailure=yes : quitte si le tunnel ne peut être établi
# - StrictHostKeyChecking=no et UserKnownHostsFile=/dev/null : désactivation de la vérification d'hôte (utile dans un environnement automatisé)
# - -vvv : mode verbeux pour obtenir des détails sur la connexion (diagnostic)

# Définir les options SSH de base
SSH_OPTIONS="-o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${verbose}"

bashio::log.info "SSH_OPTIONS: ${SSH_OPTIONS}"


###############################################################################
# Application des règles iptables pour limiter l'accès au tunnel (Version Corrigée)
###############################################################################

TUNNEL_CHAIN="HA_TUNNEL_INPUT"
TUNNEL_PORT="80"

bashio::log.info "Configuration des règles iptables pour le port ${TUNNEL_PORT} (Tunnel SOCKS)"
bashio::log.warning "ATTENTION: La commande 'iptables -F' a été supprimée pour éviter de purger les règles systèmes du Home Assistant Host."


# 1. Nettoyage de la chaîne dédiée (pour éviter la duplication des règles lors d'un redémarrage)
# On tente de supprimer l'ancienne chaîne si elle existe, et toutes les références.
# Les '|| true' permettent d'ignorer les erreurs si les règles/chaînes n'existent pas encore (à cause de set -e)
iptables -D INPUT -p tcp --dport ${TUNNEL_PORT} -j ${TUNNEL_CHAIN} 2>/dev/null || true
iptables -F ${TUNNEL_CHAIN} 2>/dev/null || true
iptables -X ${TUNNEL_CHAIN} 2>/dev/null || true

# 2. Création de la chaîne dédiée pour le filtrage du tunnel
iptables -N ${TUNNEL_CHAIN} || bashio::log.warning "La chaîne ${TUNNEL_CHAIN} existait déjà."
iptables -F ${TUNNEL_CHAIN} # S'assurer qu'elle est vide avant de la remplir


# 3. Ajout des règles d'ACCEPT dans la chaîne dédiée pour les IPs autorisées
allowed_ips_array=($(bashio::config 'allowed_ips'))
for ip in "${allowed_ips_array[@]}"; do
    bashio::log.info "Règle FW: ajout de l'IP autorisée ${ip} à la chaîne ${TUNNEL_CHAIN}"
    iptables -A ${TUNNEL_CHAIN} -s "${ip}" -j ACCEPT
done

# 4. Ajout des règles d'ACCEPT pour les MACs autorisées
allowed_macs_array=($(bashio::config 'allowed_macs'))
for mac in "${allowed_macs_array[@]}"; do
    bashio::log.info "Règle FW: ajout de la MAC autorisée ${mac} à la chaîne ${TUNNEL_CHAIN}"
    # L'implémentation originale utilisait -p tcp --dport 80, conservons cette granularité ici.
    iptables -A ${TUNNEL_CHAIN} -m mac --mac-source "${mac}" -j ACCEPT
done


# 5. Ajout de la règle de débogage pour les paquets bloqués (si activé)
if bashio::config.true 'iptable_debug'; then
    # Cette règle sera exécutée si le paquet n'a pas été ACCEPTé par les règles précédentes.
    iptables -A ${TUNNEL_CHAIN} -m limit --limit 1/s --limit-burst 3 -j LOG --log-prefix "TUNNEL BLOCKED: " --log-level 7
fi


# 6. Ajout de la règle finale de DROP dans la chaîne dédiée
# Si aucune des règles ACCEPT précédentes n'a été déclenchée, le paquet est bloqué.
iptables -A ${TUNNEL_CHAIN} -j DROP
bashio::log.info "Règle FW: Bloque l'accès au port du tunnel pour toute autre source."


# 7. Insertion du JUMP dans la chaîne INPUT principale du host
# On insère cette règle au début de la chaîne INPUT pour que notre filtrage soit appliqué en priorité.
# Cela renvoie le trafic destiné au port 80 vers notre chaîne personnalisée.
iptables -I INPUT 1 -p tcp --dport ${TUNNEL_PORT} -j ${TUNNEL_CHAIN}
bashio::log.info "Règle FW: Insertion du saut vers la chaîne ${TUNNEL_CHAIN} dans la chaîne INPUT pour le port ${TUNNEL_PORT}"


# Ajouter des logs selon iptable_debug
if bashio::config.true 'iptable_debug'; then
    #iptables -I INPUT -p tcp --dport 80 -j LOG --log-prefix "TUNNEL: " --log-level 4
    while true; do
        dmesg -c | grep "TUNNEL BLOCKED:" | while IFS= read -r line; do
            bashio::log.debug "$line"
        done
        sleep 1
    done &
fi

###############################################################################
# Lancement du tunnel SSH en mode premier plan pour que s6 supervise le processus
###############################################################################

# Remarque sur l'usage de tunnel_listen_address : 
# Dans un container HA, l'adresse IP d'écoute doit correspondre à celle sur laquelle le container accepte les connexions.
# Dans notre exemple, on utilise tunnel_listen_address tel que défini dans la configuration (souvent 0.0.0.0 ou une IP spécifique assignée au container).
if [ -f /data/ssh_keys/id_tunnel ]; then
    bashio::log.info "Lancement du tunnel SSH avec authentification par clé RSA..."
    exec ssh -ND "${tunnel_listen_address}:80" "${ssh_target}" -p "${ssh_port}" -i /data/ssh_keys/id_tunnel ${SSH_OPTIONS}
elif bashio::config.has_value 'ssh_password'; then
    SSHPASS="sshpass -p '$(bashio::config 'ssh_password')'"
    bashio::log.info "Lancement du tunnel SSH avec authentification par mot de passe..."
    exec ${SSHPASS} ssh -ND "${tunnel_listen_address}:80" "${ssh_target}" -p "${ssh_port}" ${SSH_OPTIONS}
else
    bashio::log.fatal "Aucune méthode d'authentification disponible."
    exit 1
fi
