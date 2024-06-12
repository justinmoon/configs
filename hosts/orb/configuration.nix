# NixOS configuration for OrbStack VM (aarch64)
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common
    inputs.home-manager.nixosModules.home-manager
  ];

  # OrbStack handles boot - no bootloader config needed
  boot.loader.grub.enable = false;

  networking.hostName = "orb";

  # OrbStack manages networking automatically
  networking.useDHCP = lib.mkDefault true;

  # VM-specific user overrides
  users.mutableUsers = false;
  users.groups.justin = {};
  users.users.justin = {
    group = "justin";
    extraGroups = ["docker"];
    # OrbStack uses SSH keys, but password is handy for sudo
    password = "justin";
    openssh.authorizedKeys.keys = lib.mkAfter [
      # Local VM key (no YubiKey touch needed for local VMs)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgV2paWRU+mI4al9EC3dmX83zCwQXccMmTGI/gApQZX local-vms"
    ];
  };

  # SSH - OrbStack handles SSH proxy, but enable for direct access too
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Firewall off for VM
  networking.firewall.enable = false;

  # Docker for container workflows
  virtualisation.docker.enable = true;

  # Home-manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.justin = import ../../home {
      inherit inputs;
      profile = "desktop";
      hostname = "orb";
    };
  };

  system.stateVersion = "24.11";
}
