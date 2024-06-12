# Shared Gnome desktop environment configuration
{ config, lib, pkgs, ... }:

{
  # Gnome desktop
  services.desktopManager.gnome.enable = true;

  # Sound with pipewire (Gnome requirement)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;
}
