# Shared Tailscale configuration for all hosts.
# Uses a reusable auth key from agenix so new hosts auto-join the tailnet.
#
# To generate the auth key:
#   1. Go to https://login.tailscale.com/admin/settings/keys
#   2. Generate auth key: Reusable = yes, Ephemeral = no, Expiration = none
#   3. Encrypt: echo -n 'tskey-auth-...' | age -e -R yubikeys/keys.txt -r age1mtf... -o secrets/tailscale-auth-key.age
#
# macOS (nix-darwin) handles Tailscale differently — see hosts/mac/default.nix.
{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
  };

  age.secrets.tailscale-auth-key = {
    file = ../../secrets/tailscale-auth-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
