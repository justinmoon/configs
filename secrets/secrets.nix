# Agenix secrets configuration
# This file defines which keys can decrypt which secrets.
#
# Keys:
#   - yubikey_primary: Daily driver YubiKey (no-pin, tap only)
#   - yubikey_backup: Backup YubiKey (pin once per session)
#   - server: Configs NixOS hosts (hetzner, fusion, utm, orb, fw)
#
# To edit a secret: agenix -e secrets/<name>.age -i ~/configs/yubikeys/keys.txt
# To rekey all:     agenix -r -i ~/configs/yubikeys/keys.txt

	let
	  # YubiKey: Primary (daily driver) - Slot 2, no-pin
	  yubikey_primary = "age1yubikey1q0zhu9e7zrj48zmnpx4fg07c0drt9f57e26uymgxa4h3fczwutzjjp5a6y5"; # gitleaks:allow (public age recipient)

	  # YubiKey: Backup - Slot 1
	  yubikey_backup = "age1yubikey1qtdv7spad78v4yhrtrts6tvv5wc80vw6mah6g64m9cr9l3ryxsf2jdx8gs9"; # gitleaks:allow (public age recipient)

  # Server key (deployed to /etc/age/key.txt on configs hosts)
  server = "age1mtf29wt0we3adcja7k0ylc9hmf2fns3c44qz9g663l0ydepxqdrq94jzzf";

  # Key groups
  personalKeys = [ yubikey_primary yubikey_backup ];
  allKeys = [ yubikey_primary yubikey_backup server ];
in {
  # Server-deployed secrets (need server key for nixos-rebuild)
  "github-ssh-key.age".publicKeys = allKeys;
  "monorepo-deploy-key.age".publicKeys = allKeys;
  "nix-cache-key.age".publicKeys = allKeys;
  "hetzner-ssh-key.age".publicKeys = allKeys;
  "local-vm-key.age".publicKeys = allKeys;
  "tailscale-auth-key.age".publicKeys = allKeys;

  # Local-only secrets (macOS, no server key needed)
  "r2.age".publicKeys = personalKeys;
}
