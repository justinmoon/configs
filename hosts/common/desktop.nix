# Shared desktop settings for all graphical Linux hosts (fw, vm - not hetzner)
{ config, lib, pkgs, ... }:

{
  # Tailscale: enabled via common/default.nix -> common/tailscale.nix

  # Fonts
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      fira-code
      jetbrains-mono
      nerd-fonts.fira-code
    ];
  };

  # X11 configuration
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    # Enable libinput for touchpad/mouse
    libinput = {
      enable = true;
      # Natural scrolling (Mac-style) for all devices
      naturalScrolling = true;
    };
  };

  # Display manager with both i3 and Gnome available
  services.displayManager.gdm.enable = true;
  services.xserver.displayManager.sessionCommands = ''
    # Faster key repeat
    xset r rate 150 40
    # Set DPI for HiDPI displays
    xrandr --dpi 180
  '';

  # Sound with PipeWire
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

  # Keyboard remapping (base config)
  # - CapsLock → Control
  # - Shift+CapsLock → toggle CapsLock
  # Host-specific configs can override/extend via lib.mkForce
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        main = {
          capslock = "leftcontrol";
        };
        shift = {
          capslock = "capslock";
        };
      };
    };
  };

  # Common desktop packages
  environment.systemPackages = with pkgs; [
    vim
    git
    tmux
    ghostty
    dmenu
  ];

  # Browsers
  programs.firefox.enable = true;
  programs.ladybird.enable = true;

  # Brightness control (no sudo required)
  programs.light.enable = true;

  # 1Password
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "justin" ];
  };

  # Tailscale: enabled via common/tailscale.nix
}
