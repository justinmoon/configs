---
summary: SSH keys, age keys, and encrypted secrets inventory
read_when:
  - adding new secrets
  - debugging SSH access
  - rotating keys
  - setting up new host
---

# Keys & Secrets

## Personal SSH Keys

| Key | Location | Access |
|-----|----------|--------|
| 1Password key | `~/.ssh/id_ed25519` (installed via `just install-ssh-key`) | Remote hosts (default) |
| Local VM key | `~/.ssh/id_ed25519_local` | orb, fusion, utm (no touch) |
| GitHub key | `~/.ssh/id_ed25519_github` | Git operations (no YubiKey) |
| Hetzner key | `~/.ssh/id_ed25519_hetzner` | Hetzner + forge (no YubiKey) |

Optional: YubiKey-backed `sk-ssh-ed25519@openssh.com` keys can still be authorized on hosts, but we no longer track any `id_ed25519_sk_*` handle files in this repo because they look like private keys to scanners. If you need them, keep them local under `~/.ssh/`.

**Emergency access:** If `~/.ssh/id_ed25519` isn't available, run `ssh-1password-load` to temporarily load the 1Password key into your agent. Run `ssh-1password-unload` when done.

**Local VMs:** The local VM key is encrypted in `secrets/local-vm-key.age` and auto-decrypted on first `darwin-rebuild switch`. No YubiKey touch needed for local VM access.

**Audit:** Run `ssh-audit` to see which keys are present in `~/.ssh` vs which `IdentityFile` entries are actually used by your `~/.ssh/config`.

## Age Keys (sops secrets encryption)

| Key | Location | Purpose |
|-----|----------|---------|
| YubiKey primary | On device (`age1yubikey1qfj07...`) | Decrypt secrets |
| YubiKey backup | On device (`age1yubikey1qtdv7...`) | Decrypt secrets |
| 1Password backup | `op://cli/age/passphrase` | Emergency decrypt |

Configured in `.sops.yaml`. All three keys can decrypt any secret in `secrets/`.

## Encrypted Secrets (`secrets/`)

| File | Contents |
|------|----------|
| `github-ssh-key.age` | SSH key for GitHub access |
| `monorepo-deploy-key.age` | SSH key for monorepo CI deploys |
| `nix-cache-key.age` | Nix binary cache signing key |
| `hetzner-ssh-key.age` | Hetzner SSH access key |
| `local-vm-key.age` | SSH key for local VMs (orb/fusion/utm) |
| `age.key.enc` | Age private key (encrypted with passphrase from 1Password) |
| `age.pub` | Age public key |

## Service-to-Service SSH Keys

| Key | Authorized On | Purpose |
|-----|---------------|---------|
| `monorepo-deploy-2025-11-30` | hetzner (root) | CI deploys to hetzner |

## Host SSH Access

All NixOS hosts authorize these keys for user `justin`:
- YubiKey primary
- YubiKey backup
- 1Password backup

Configured in `hosts/common/default.nix`.

Hetzner root additionally authorizes `monorepo-deploy` for CI.
