# Sandbox NixOS configuration for Hetzner Cloud VMs
# This is a lightweight config for ephemeral coding sandboxes.
# 
# Note: This config intentionally doesn't use agenix for simplicity.
# GitHub auth uses deploy keys or manual setup.
#
# Usage:
#   nixos-rebuild switch --flake ~/configs#sandbox
#
{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  nodejs = pkgs.nodejs_22;

  # Coding agent CLI wrappers
  claude-cli = pkgs.writeShellScriptBin "claude" ''
    exec ${nodejs}/bin/npx --yes @anthropic-ai/claude-code "$@"
  '';

  pi-cli = pkgs.writeShellScriptBin "pi" ''
    exec ${nodejs}/bin/npx --yes @mariozechner/pi-coding-agent "$@"
  '';

  # Use 'sprite' profile - lighter than 'remote', excludes heavy packages like whisper
  sandboxHomeModule = import ../../home {
    inherit inputs;
    profile = "sprite";
    hostname = "sandbox";
  };
in
{
  imports = [
    # Hetzner/QEMU guest support
    (modulesPath + "/profiles/qemu-guest.nix")
    # Disk configuration (for nixos-anywhere)
    ./disk-config.nix
    # Home-manager
    inputs.home-manager.nixosModules.home-manager
    # NOTE: We don't import ../common because it requires agenix
  ];

  # Locale settings (from common)
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/Los_Angeles";

  # Disable documentation to avoid man-cache build issues on remote builder
  documentation = {
    enable = false;
    man.enable = false;
    doc.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  # Boot configuration for Hetzner (UEFI + BIOS compatible via disko)
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "/dev/sda";
  };
  boot.initrd.availableKernelModules = [ 
    "ata_piix" "virtio_pci" "virtio_scsi" "virtio_blk"
    "xhci_pci" "sd_mod" "sr_mod" 
  ];
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Filesystem configured by disko (see disk-config.nix)
  # Don't define fileSystems here - disko handles it

  # Swap (optional, good for Nix builds)
  swapDevices = [{
    device = "/swapfile";
    size = 4096;  # 4GB
  }];

  networking.hostName = "sandbox";

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

  # User configuration
  users.users.justin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # 1Password SSH key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9qcRB7tF1e8M9CX8zoPfNmQgWqvnee0SKASlM0aMlm mail@justinmoon.com"
      # YubiKey primary
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOvnevaL7FO+n13yukLu23WNfzRUPzZ2e3X/BBQLieapAAAABHNzaDo= justin@yubikey-primary"
      # YubiKey backup
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMrMVMYKXjA7KuxacP6RexsSfXrkQhwOKwGAfJExDxYZAAAABHNzaDo= justin@yubikey-backup"
    ];
  };

  # Passwordless sudo
  security.sudo.wheelNeedsPassword = false;

  # Home-manager for justin
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.justin = sandboxHomeModule;
    extraSpecialArgs = { inherit inputs; };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Essentials
    git
    gh
    vim
    tmux
    htop
    
    # Dev tools
    ripgrep
    fd
    jq
    curl
    wget
    
    # Node for coding agents
    nodejs
    claude-cli
    pi-cli
    
    # Build tools
    gnumake
    gcc
  ];

  # SSH server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Enable fish shell
  programs.fish.enable = true;
  environment.pathsToLink = [ "/share/fish" ];

  # nix-ld for dynamically linked binaries
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      glibc
      zlib
    ];
  };

  # GitHub known hosts (for git operations)
  programs.ssh.knownHosts."github.com" = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  # Auto-shutdown: 24h idle or 48h max lifetime
  # This prevents forgotten VMs from running up costs
  
  # Record boot time and schedule hard 48h cutoff
  systemd.services.sandbox-lifetime = {
    description = "Sandbox lifetime manager";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Record start time
      mkdir -p /var/lib/sandbox
      date +%s > /var/lib/sandbox/start-time
      
      # Hard cutoff at 48 hours
      ${pkgs.systemd}/bin/systemd-run --on-active=48h --unit=sandbox-hard-shutdown ${pkgs.systemd}/bin/poweroff
      
      echo "Sandbox will auto-shutdown in 48h max"
    '';
  };

  # Idle checker: shutdown if no SSH sessions for 24h
  systemd.services.sandbox-idle-check = {
    description = "Check for idle sandbox";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.procps pkgs.coreutils pkgs.iproute2 ];
    script = ''
      IDLE_THRESHOLD=86400  # 24 hours in seconds
      
      # Check for active SSH sessions
      if pgrep -x sshd > /dev/null; then
        SSH_CONNECTIONS=$(ss -tn state established '( dport = :22 or sport = :22 )' 2>/dev/null | wc -l)
        if [ "$SSH_CONNECTIONS" -gt 0 ]; then
          # Active SSH connections, update last activity
          date +%s > /var/lib/sandbox/last-activity
          exit 0
        fi
      fi
      
      # Check last activity time
      if [ -f /var/lib/sandbox/last-activity ]; then
        LAST_ACTIVITY=$(cat /var/lib/sandbox/last-activity)
      else
        # No activity recorded, use start time
        LAST_ACTIVITY=$(cat /var/lib/sandbox/start-time 2>/dev/null || date +%s)
      fi
      
      NOW=$(date +%s)
      IDLE_TIME=$((NOW - LAST_ACTIVITY))
      
      if [ "$IDLE_TIME" -gt "$IDLE_THRESHOLD" ]; then
        echo "Idle for $IDLE_TIME seconds (threshold: $IDLE_THRESHOLD), shutting down..."
        ${pkgs.systemd}/bin/poweroff
      else
        REMAINING=$((IDLE_THRESHOLD - IDLE_TIME))
        echo "Idle for $IDLE_TIME seconds, $REMAINING seconds until auto-shutdown"
      fi
    '';
  };

  systemd.timers.sandbox-idle-check = {
    description = "Periodic idle check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "10min";
      Persistent = true;
    };
  };

  # Firewall: allow SSH only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "24.11";
}
