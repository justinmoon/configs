# Shared NixOS settings for all Linux hosts
{ config, lib, pkgs, ... }:

{
  imports = [
    ./github-ssh.nix
    ./tailscale.nix
  ];
  # Locale settings
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Timezone
  time.timeZone = "America/Los_Angeles";

  # Use latest kernel for best hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Nix settings
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "justin" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Fish shell
  programs.fish.enable = true;
  environment.pathsToLink = [ "/share/fish" ];
  environment.localBinInPath = true;

  # nix-ld: Run dynamically linked binaries (e.g. droid, other prebuilt tools)
  # The stub-ld is enabled by default in NixOS 25.x but only prints an error.
  # This actually provides the dynamic linker and libraries needed to run them.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      glibc
      zlib
    ];
  };

  # Common user setup
  users.users.justin = {
    isNormalUser = true;
    description = "justin";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # 1Password SSH key (backup)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9qcRB7tF1e8M9CX8zoPfNmQgWqvnee0SKASlM0aMlm mail@justinmoon.com"
      # YubiKey primary
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOvnevaL7FO+n13yukLu23WNfzRUPzZ2e3X/BBQLieapAAAABHNzaDo= justin@yubikey-primary"
      # YubiKey backup
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMrMVMYKXjA7KuxacP6RexsSfXrkQhwOKwGAfJExDxYZAAAABHNzaDo= justin@yubikey-backup"
    ];
  };

  # Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = false;
}
