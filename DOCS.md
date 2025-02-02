# Documentation – ha ssh proxy tunnel

## Description
The **ha ssh proxy tunnel** add-on creates a dynamic SSH tunnel (SOCKS proxy) to redirect traffic, with IP-based access filtering and flexible authentication (via RSA key or password). It automatically generates an SSH key pair if none exists and provides an option for debug logging.

## Features
- **Dynamic SSH Tunnel (SOCKS Proxy):** Redirects traffic over an SSH tunnel.
- **IP Filtering:** Only clients with IPs listed in `allowed_ips` can access the tunnel.
- **Flexible Authentication:** Supports using an RSA key (automatically generated if missing) or a password.
- **Automatic Key Generation:** If the file `/data/ssh_keys/id_tunnel` does not exist, a key pair is generated based on the configured options (`key_algo`, `key_length`, and `key_passphrase`). The public key is output in the logs so you can add it to the remote server’s `authorized_keys`.
- **Debug Mode:** When enabled (via the `debug` option), detailed SSH logs (using `-vvv`) are provided for troubleshooting.

## Configuration (config.yaml)
The following options are available:

- **allowed_ips** (`str`)  
  A comma-separated list of IP addresses allowed to access the tunnel (e.g., `"127.0.0.1"` or `"192.168.8.126,192.168.8.100"`).

- **ssh_target** (`str`)  
  The remote SSH destination in the format `user@mydomain.com` (the remote server to connect to).

- **ssh_port** (`int`)  
  The SSH port on the remote server (default is 22).

- **ssh_password** (`password?`)  
  The SSH password (leave empty if using RSA key authentication).

- **key_algo** (`list(dsa|ecdsa|ecdsa-sk|ed25519|ed25519-sk|rsa)`)  
  The algorithm to use when generating the SSH key (default is `"rsa"`).

- **key_length** (`int`)  
  The key length for RSA, DSA, or ECDSA (e.g., `3072`).

- **key_passphrase** (`password?`)  
  The passphrase to protect the generated SSH key (leave empty for no passphrase).

- **tunnel_listen_address** (`str`)  
  The address on which the tunnel listens inside the container (typically `"0.0.0.0"` to listen on all interfaces).

- **debug** (`bool`)  
  Enable detailed SSH logging (adds the `-vvv` flag when `true`).

### Ports Section
In your **config.yaml**, the ports section is defined as follows:

```yaml
ports:
  80/tcp: 3001
ports_description:
  80/tcp: "Tunnel Listen Port"
