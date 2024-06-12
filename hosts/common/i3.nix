# Shared i3 window manager configuration
{ config, lib, pkgs, ... }:

{
  # X11 with i3
  services.xserver = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      package = pkgs.i3;
      extraPackages = with pkgs; [ i3status dmenu ];
    };
  };

  # i3-specific packages
  environment.systemPackages = with pkgs; [
    ghostty
    gtkmm3
    flameshot
    xclip
  ];
}
