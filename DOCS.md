# Documentation – ha ssh proxy tunnel

## Description
L'addon **ha ssh proxy tunnel** permet d'ouvrir un tunnel SSH dynamique (proxy SOCKS) pour rediriger le trafic, avec filtrage d'accès par adresses IP et authentification flexible (clé RSA ou mot de passe). Il génère automatiquement une paire de clés SSH si aucune n'est présente, et propose une option de débogage pour obtenir des logs détaillés.

## Fonctionnalités
- **Tunnel SSH dynamique (proxy SOCKS)** : redirige le trafic via SSH.
- **Filtrage par IP** : seuls les clients dont l'IP figure dans la liste `allowed_ips` peuvent accéder au tunnel.
- **Authentification flexible** : utilisation d'une clé RSA ou d'un mot de passe.
- **Génération automatique de clé** : si le fichier de clé n'existe pas dans le dossier persistant `/data/ssh_keys`, une paire est générée en fonction des paramètres `key_algo`, `key_length` et `key_passphrase`.
- **Mode Debug** : active des logs détaillés (`-vvv`) pour diagnostiquer les connexions SSH.

## Configuration (config.yaml)
Les options configurables sont :

- **allowed_ips** (`str`)  
  Liste des adresses IP autorisées à accéder au tunnel (exemple : `"127.0.0.1"` ou `"192.168.8.126,192.168.8.100"`).

- **ssh_target** (`str`)  
  Destination SSH au format `user@mydomain.com` (le serveur distant auquel se connecter).

- **ssh_port** (`int`)  
  Port SSH du serveur distant (par défaut 22).

- **ssh_password** (`password?`)  
  Mot de passe SSH (laisser vide si utilisation de la clé RSA).

- **key_algo** (`list(dsa|ecdsa|ecdsa-sk|ed25519|ed25519-sk|rsa)`)  
  Algorithme pour la génération de la clé (par défaut `"rsa"`).

- **key_length** (`int`)  
  Longueur de la clé pour rsa, dsa ou ecdsa (par exemple `3072`).

- **key_passphrase** (`password?`)  
  Passphrase pour protéger la clé SSH générée (laisser vide pour aucune passphrase).

- **tunnel_listen_address** (`str`)  
  Adresse d'écoute du tunnel à l'intérieur du container (souvent `"0.0.0.0"` pour écouter sur toutes les interfaces).

- **debug** (`bool`)  
  Active ou désactive les logs détaillés SSH (ajoute l'option `-vvv` lorsque `true`).

### Section Ports
La section suivante dans **config.yaml** définit le mapping des ports :

```yaml
ports:
  80/tcp: 3001
ports_description:
  80/tcp: Tunnel Listen Port
