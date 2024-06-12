# Modal sandbox host configuration
# This defines the NixOS system for Modal sandboxes running coding agents.
#
# Usage:
#   nix build .#nixosConfigurations.modal.config.system.build.toplevel
#   Or used by cook CLI to configure sandboxes
{ config, lib, pkgs, inputs, ... }:

let
  nodejs = pkgs.nodejs_22;
  
  # Coding agent wrappers
  claude-cli = pkgs.writeShellScriptBin "claude" ''
    exec ${nodejs}/bin/npx --yes @anthropic-ai/claude-code "$@"
  '';
  
  codex-cli = pkgs.writeShellScriptBin "codex" ''
    exec ${nodejs}/bin/npx --yes @openai/codex "$@"
  '';
  
  opencode-cli = pkgs.writeShellScriptBin "opencode" ''
    exec ${nodejs}/bin/npx --yes opencode-ai "$@"
  '';
  
  remoteHomeModule = import ../../home {
    inherit inputs;
    profile = "remote";
    hostname = "modal";
  };
in
{
  # Basic system config for containers/sandboxes
  boot.isContainer = true;
  
  # No bootloader needed in container
  boot.loader.grub.enable = false;
  
  networking.hostName = "modal";
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # System packages - coding agents and essentials
  environment.systemPackages = with pkgs; [
    git
    gh
    just
    ripgrep
    fd
    jq
    curl
    wget
    htop
    tmux
    nodejs
    claude-cli
    codex-cli
    opencode-cli
  ];
  
  # Create agent user
  users.users.agent = {
    isNormalUser = true;
    home = "/home/agent";
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };
  
  # Passwordless sudo for agent
  security.sudo.wheelNeedsPassword = false;
  
  # Home-manager for agent user
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.agent = args@{ pkgs, ... }:
      let
        base = remoteHomeModule args;
      in
        base // {
          home = base.home // {
            username = "agent";
            homeDirectory = "/home/agent";
          };
        };
  };
  
  # Enable fish shell
  programs.fish.enable = true;
  
  system.stateVersion = "24.05";
}
