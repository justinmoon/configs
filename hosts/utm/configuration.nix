# NixOS configuration for UTM VM (aarch64) with i3
{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
    ../common
    ../common/desktop.nix
    ../common/i3.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "0";

  networking.hostName = "utm";
  networking.useDHCP = lib.mkForce true;

  # UTM/QEMU uses different interface name than VMware
  # This will be auto-detected but we force DHCP just in case
  networking.interfaces.enp0s1.useDHCP = lib.mkDefault true;

  # Force Google DNS (can help with QEMU NAT issues)
  environment.etc."resolv.conf".text = ''
    nameserver 8.8.8.8
    nameserver 8.8.4.4
  '';

  # Allow unsupported packages (some aarch64 packages need this)
  nixpkgs.config.allowUnsupportedSystem = true;

  # SPICE agent for clipboard, display resize, etc.
  # DISABLED: Causes UTM SwiftUI crashes on macOS Tahoe beta
  # Re-enable once UTM fixes compatibility with macOS 26.x
  services.spice-vdagentd.enable = false;

  # Software rendering - hardware accel often broken on UTM/QEMU
  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  # Helpful scripts for display management
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "xrandr-auto" ''
      xrandr --output Virtual-1 --auto
    '')
    (writeShellScriptBin "xrandr-utm" ''
      # Custom resolution for M5 MacBook (3200x2016 matches UTM fullscreen)
      xrandr --newmode "3200x2016_60.00" 552.71 3200 3456 3808 4416 2016 2017 2020 2086 -HSync +Vsync 2>/dev/null
      xrandr --addmode Virtual-1 3200x2016_60.00 2>/dev/null
      xrandr --output Virtual-1 --mode 3200x2016_60.00
    '')
  ];

  # Set custom resolution on X startup
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "3200x2016_60.00" 552.71 3200 3456 3808 4416 2016 2017 2020 2086 -HSync +Vsync 2>/dev/null || true
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode Virtual-1 3200x2016_60.00 2>/dev/null || true
    ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --mode 3200x2016_60.00 2>/dev/null || true
  '';

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
      hostname = "utm";
    };
  };

  system.stateVersion = "25.11";
}
