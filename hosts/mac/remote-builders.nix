# Remote builders configuration for macOS with Determinate Nix
# Enables building Linux packages on remote NixOS machines
#
# NOTE: Because darwin.nix has `nix.enable = false` (required by Determinate Nix),
# nix-darwin doesn't manage nix configuration. Instead, we create /etc/nix files directly.

{ config, pkgs, lib, ... }:

{
  # Create /etc/nix/machines file for remote builders
  environment.etc."nix/machines".text = ''
    ssh://justin@135.181.179.143 x86_64-linux /Users/justin/.ssh/id_ed25519 4 2 nixos-test,benchmark,big-parallel,kvm
  '';
  
  # Add to /etc/nix/nix.custom.conf (which is included by nix.conf)
  environment.etc."nix/nix.custom.conf".text = lib.mkAfter ''
    # Remote builder configuration
    builders-use-substitutes = true
    trusted-users = root justin
  '';
}
