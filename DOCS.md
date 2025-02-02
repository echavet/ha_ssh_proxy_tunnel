<!-- DOC.md -->
# Documentation – ha ssh proxy tunnel

## Fonctionnalités
- Ouvre un tunnel SSH créant un proxy SOCKS sur l'adresse et le port configurés.
- Limite l'accès au tunnel via des règles iptables basées sur une liste d'IP autorisées.
- Authentification SSH configurable par mot de passe ou par clé RSA.

## Configuration (config.yaml)
- **allowed_ips** : Liste des IP autorisées (séparées par des virgules).
- **ssh_target** : Destination SSH (format `user@host`).
- **ssh_port** : Port SSH de la destination.
- **ssh_password** : Mot de passe SSH. Laisser vide si vous utilisez une clé RSA.
- **authorized_keys** : Contenu complet de la clé RSA (clé privée) pour l'authentification. Si non vide, utilisée à la place du mot de passe.
- **tunnel_listen_address** : Adresse d'écoute du tunnel.
- **tunnel_listen_port** : Port d'écoute du tunnel.

## Démarrage
L'addon configure le pare-feu pour n'autoriser que les IP définies puis lance le tunnel SSH.
- Si **authorized_keys** est fourni, la clé est écrite dans `/root/.ssh/id_rsa` et utilisée avec l'option `-i`.
- Sinon, si **ssh_password** est renseigné, `sshpass` est utilisé pour fournir le mot de passe.
- En absence des deux, le démarrage échoue.

## Personnalisation
Modifiez le fichier YAML pour adapter les paramètres à votre environnement.
