# NixOS configuration for Framework laptop
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../common/desktop.nix
    ../common/i3.nix
    ../common/gnome.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fw";
  networking.networkmanager.enable = true;

  # High DPI display setting for Framework 2.8K display (2880x1920)
  services.xserver.dpi = 180;

  # CPU frequency scaling for better responsiveness
  # Use schedutil (default) or performance governor instead of powersave
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  # Framework-specific: Also swap Alt and Super (Meta) keys
  # (CapsLock→Control comes from desktop.nix)
  services.keyd.keyboards.default.settings.main = lib.mkForce {
    leftalt = "leftmeta";
    leftmeta = "leftalt";
    capslock = "leftcontrol";
  };

  # Home-manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.justin = import ../../home {
      inherit inputs;
      profile = "desktop";
      hostname = "fw";
    };
  };

  system.stateVersion = "25.05";
}
