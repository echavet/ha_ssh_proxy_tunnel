<!-- README.md -->
# ha ssh proxy tunnel

Addon pour Home Assistant permettant d'ouvrir un tunnel SSH servant de proxy SOCKS, avec limitation d'accès par IP et authentification configurable (mot de passe ou clé RSA).

- **Tunnel SSH** : Proxy SOCKS sur l'adresse et le port définis.
- **Sécurité** : Règles iptables pour limiter l'accès aux IP autorisées.
- **Authentification** : Support du mot de passe ou d'une clé RSA (paramètre authorized_keys).

Voir DOC.md pour la documentation complète.
