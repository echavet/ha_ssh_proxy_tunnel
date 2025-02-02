---

**README.md**

```markdown
# ha ssh proxy tunnel

Addon pour Home Assistant permettant d'ouvrir un tunnel SSH dynamique (proxy SOCKS) avec filtrage d'accès par IP et authentification flexible (clé RSA ou mot de passe).

## Caractéristiques

- **Tunnel SSH dynamique :** redirige le trafic via SSH en mode proxy SOCKS.
- **Filtrage par IP :** seuls les clients dont l'IP figure dans `allowed_ips` peuvent accéder au tunnel.
- **Authentification flexible :** possibilité d'utiliser une clé RSA (générée automatiquement si nécessaire) ou un mot de passe.
- **Option Debug :** active des logs détaillés pour faciliter le diagnostic.
- **Mapping de port :** le tunnel écoute sur le port interne 80, qui est mappé vers le port configuré (par défaut 3001) sur l'hôte.

## Installation

1. Ajoutez le dépôt GitHub de l'addon à Home Assistant :  
   [https://github.com/echavet/ha_ssh_proxy_tunnel](https://github.com/echavet/ha_ssh_proxy_tunnel)
2. Installez l'addon et configurez-le via le fichier **config.yaml**.
3. Redémarrez l'addon.

## Exemple de configuration (config.yaml)

```yaml
name: "ha ssh proxy tunnel"
slug: "ha_ssh_proxy_tunnel"
description: "Addon permettant d'ouvrir un tunnel SSH avec proxy SOCKS, de limiter l'accès par IP et de gérer l'authentification par mot de passe ou clé RSA."
version: "2025.2.2-beta-1.2"
maintainer: "echavet@gmail.com"
url: "https://github.com/echavet/ha_ssh_proxy_tunnel"

init: false

arch:
  - aarch64
  - amd64
  - armhf
  - armv7
  - i386
  
privileged:
  - NET_ADMIN  
  
map:
  - ssh_keys:rw
  - addons:r
  - homeassistant_config:rw  
  - share:rw
  - ssl:rw
ports:
  80/tcp: 3001
ports_description:
  80/tcp: Tunnel Listen Port
  
options:
  allowed_ips: "127.0.0.1"
  ssh_target: "user@mydomain.com"
  ssh_port: 22
  ssh_password: ""    
  tunnel_listen_address: "0.0.0.0"
  key_algo: "rsa"
  key_length: 3072
  key_passphrase: ""
  debug: false

schema:
  allowed_ips: str
  ssh_target: str
  ssh_port: int
  ssh_password: password?
  key_algo: list(dsa|ecdsa|ecdsa-sk|ed25519|ed25519-sk|rsa)
  key_length: int
  key_passphrase: password?
  tunnel_listen_address: str
  debug: bool
