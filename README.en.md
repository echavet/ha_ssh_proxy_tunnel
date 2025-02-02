
---

**README.en.md**

```markdown
# ha ssh proxy tunnel

An add-on for Home Assistant that creates a dynamic SSH tunnel (SOCKS proxy) with IP-based access filtering and flexible authentication (RSA key or password).

## Features

- **Dynamic SSH Tunnel:** Redirects traffic via an SSH tunnel operating as a SOCKS proxy.
- **IP Filtering:** Only clients with IP addresses listed in `allowed_ips` can access the tunnel.
- **Flexible Authentication:** Supports RSA key authentication (automatically generated if needed) or a password.
- **Automatic Key Generation:** If no key exists at `/data/ssh_keys/id_tunnel`, a new RSA key pair is generated using the configured parameters. The public key is output in the logs so you can add it to the remote server.
- **Debug Mode:** When enabled, detailed SSH logs (`-vvv`) are provided to aid troubleshooting.
- **Port Mapping:** The SSH tunnel listens on port **80** inside the container, which is mapped to an external port (default is 3001) as configured in the add-on settings.

## Installation

1. Add the add-on repository to Home Assistant:  
   [https://github.com/echavet/ha_ssh_proxy_tunnel](https://github.com/echavet/ha_ssh_proxy_tunnel)
2. Install the add-on and configure it via **config.yaml**.
3. Restart the add-on.

## Sample Configuration (config.yaml)

```yaml
name: "ha ssh proxy tunnel"
slug: "ha_ssh_proxy_tunnel"
description: "Add-on to create an SSH tunnel with a SOCKS proxy, IP filtering, and flexible authentication (password or RSA key)."
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
  80/tcp: "Tunnel Listen Port"
  
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
