# NixOS configuration for VMware Fusion VM (aarch64) with i3
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./vmware-guest.nix
    ../common
    ../common/desktop.nix
    ../common/i3.nix
    ../common/gnome.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Disable built-in vmware-guest module to avoid conflict with custom module
  disabledModules = [ "virtualisation/vmware-guest.nix" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "0";

  networking.hostName = "fusion";
  networking.useDHCP = lib.mkForce true;

  # Advertise hostname via mDNS so we can ssh to fusion.local
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # VMware's NAT DNS resolver is unreliable, force Google DNS
  environment.etc."resolv.conf".text = ''
    nameserver 8.8.8.8
    nameserver 8.8.4.4
  '';

  # Allow unsupported packages (some aarch64 packages need this)
  nixpkgs.config.allowUnsupportedSystem = true;

  # VMware guest support (using custom aarch64-compatible module)
  virtualisation.vmware.guest.enable = true;

  # Share host filesystem
  fileSystems."/host" = {
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    device = ".host:/";
    options = [
      "umask=22"
      "uid=1000"
      "gid=1000"
      "allow_other"
      "auto_unmount"
      "defaults"
    ];
  };

  # VM-specific user overrides (password auth, mutable=false)
  users.mutableUsers = false;
  users.groups.justin = {};
  users.users.justin = {
    group = "justin";
    extraGroups = ["docker"];
    password = "justin";
    openssh.authorizedKeys.keys = lib.mkAfter [
      # Local VM key (no YubiKey touch needed for local VMs)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgV2paWRU+mI4al9EC3dmX83zCwQXccMmTGI/gApQZX local-vms"
    ];
  };

  # VM-specific: High DPI setting
  services.xserver.dpi = 180;

  # SSH with password auth for VM convenience
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Firewall off for VM
  networking.firewall.enable = false;

  # Home-manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.justin = import ../../home {
      inherit inputs;
      profile = "desktop";
      hostname = "fusion";
    };
  };

  system.stateVersion = "25.11";
}
