# Hetzner Server Configuration

This directory contains NixOS configuration for the Hetzner server.

## Deployment

```bash
just switch hetzner
```

This runs remotely on the Hetzner host and does not require local sudo.

## Services

| Service | File | Domain / Port | Description |
|---------|------|---------------|-------------|
| **Caddy** | `caddy.nix` | :80/:443 | Reverse proxy with wildcard TLS via Namecheap DNS challenge |
| **Bitcoin Core** | `bitcoin.nix` | :8333 (P2P) | Pruned node (2GB), `bitcoin-cli` wrapper available |
| **Immich** | `immich.nix` | `photos.justinmoon.com` | Self-hosted photo management |
| **MoQ Relay** | `moq.nix` | `moq.justinmoon.com` (UDP :443) | Media over QUIC relay, uses Caddy certs |
| **strfry (Nostr relay)** | `strfry.nix` | `relay.justinmoon.com` | Nostr relay (websocket via Caddy) |
| **Nix Cache** | `nix-cache.nix` | Tailscale :5000 | `nix-serve` binary cache (Tailscale-only) |
| **Tailscale** | `configuration.nix` | — | Mesh VPN |
| **Cuttlefish** | `configuration.nix` | — | Android emulator (cfctl daemon + FHS environment) |

Other Caddy routes: `static.justinmoon.com` (file browser), `setup.justinmoon.com` (redirect), `vibe.justinmoon.com` (static), `www.justinmoon.com` → `justinmoon.com`.

Tailscale-only services: SSH (:22), Immich (:2283), Nix Cache (:5000), Syncthing (:22000).

## Namecheap Wildcard DNS Certificates

- Create a Namecheap API key (Profile → Tools → API Access), paste it into the 1Password item `cli/namecheap/api_key`, and keep the API user set to `stockninja`.
- Add the server's public IP to the Namecheap API whitelist; update it whenever the Hetzner host changes.
- Push the credentials to the box so Caddy can solve DNS challenges: `REMOTE=justin@<server-ip> scripts/push-namecheap-env.sh`. The script uses the 1Password CLI (`op`) to render `/etc/secrets/namecheap-dns.env` with `NAMECHEAP_API_USER`, `NAMECHEAP_API_KEY`, and `NAMECHEAP_CLIENT_IP` (ensure the `CLIENT_IP` constant in the script matches the whitelisted IP).
- Rebuild (`nixos-rebuild switch`) and restart Caddy after the secret lands; it will request a wildcard certificate covering `*.justinmoon.com`.

## Secrets (agenix)

Secrets are defined in `secrets/secrets.nix` and encrypted with age keys (YubiKeys + server key).

| Secret | Used by |
|--------|---------|
| `github-ssh-key.age` | SSH access to GitHub |
| `monorepo-deploy-key.age` | Monorepo CI deploys |
| `nix-cache-key.age` | Nix binary cache signing |
| `hetzner-ssh-key.age` | Hetzner SSH access |

To edit a secret: `agenix -e secrets/<name>.age -i ~/configs/yubikeys/keys.txt`
