{
  pkgs,
  inputs,
  config,
  system,
  ...
}: {
  imports = [
    ./linux-builder.nix
  ];

  # FIXME: Why can't I remove this? It's already set in home/default.nix?
  programs.fish.enable = true;

  # Necessary for using flakes on this system.
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Set the primary user for nix-darwin
  system.primaryUser = "justin";

  # Set hostname declaratively
  networking.hostName = "mac";
  networking.computerName = "mac";
  networking.localHostName = "mac";

  # Users
  users.users.justin = {
    home = "/Users/justin";
    shell = pkgs.fish;
  };

  # Didn't copy over any packages. Next time I setup a new computer, try to install
  # as much as possible via nix
  homebrew = {
    enable = true;
    taps = [
      "cirruslabs/cli"
    ];
    brews = [
      "imageoptim-cli"
      "cirruslabs/cli/tart"  # macOS VMs for testing setup script
    ];
    casks = [
      "1password"
      "discord"
      "ghostty"
      "google-chrome"
      "helium-browser"
      "obscura-vpn"
      "obs"
      "orbstack"
      "signal"
      "sparrow"
      "spotify"
      "superwhisper"
      "claude-code"
      "utm"
      "vlc"
      "vscodium"
      "wispr-flow"
      "zed"
    ];
  };

  # Faster key repeat
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;

  # Auto-hide the Dock
  system.defaults.dock.autohide = true;

  # Remap Caps Lock to Control
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  # Allow proprietary software
  nixpkgs.config.allowUnfree = true;

  # Skip building extra documentation that triggers noisy options.json warnings
  documentation.enable = false;

  # Nix configuration (managed by nix-darwin)
  nix.enable = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "justin" ];
    builders-use-substitutes = true;
    download-buffer-size = 256 * 1024 * 1024; # 256 MiB
  };

  # System-wide known_hosts so the nix-daemon (root) can reach the Hetzner builder.
  environment.etc."ssh/ssh_known_hosts".text = ''
    # hetzner remote builder
    135.181.179.143 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICXARrNYBbxNZDGiMWh63DZP6Vu6Rh/Q3fpKh0OMIBOt
  '';

  # Match the GID used by Determinate Nix installer (which we migrated from)
  ids.gids.nixbld = 350;

  services.tailscale = {
    enable = true;
  };

  # Increase file descriptor limits for building large projects
  launchd.daemons."limit.maxfiles" = {
    serviceConfig = {
      Label = "limit.maxfiles";
      ProgramArguments = [
        "launchctl"
        "limit"
        "maxfiles"
        "65536"
        "524288"
      ];
      RunAtLoad = true;
    };
  };
  
  launchd.user.agents."limit.maxfiles" = {
    serviceConfig = {
      Label = "limit.maxfiles";
      ProgramArguments = [
        "launchctl"
        "limit"
        "maxfiles"
        "65536"
        "524288"
      ];
      RunAtLoad = true;
    };
  };
}
