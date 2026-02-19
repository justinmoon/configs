{ config, lib, pkgs, modulesPath, inputs, cuttlefish, ... }:

let
  nodejs = pkgs.nodejs_22;

  claude-cli = pkgs.writeShellScriptBin "claude" ''
    exec ${nodejs}/bin/npx --yes @anthropic-ai/claude-code "$@"
  '';

  opencode-cli = pkgs.writeShellScriptBin "opencode" ''
    exec ${nodejs}/bin/npx --yes opencode-ai "$@"
  '';

  basePackages = with pkgs; [
    vim
    git
    htop
    tmux
    lsof        # List open files and ports
    netcat      # Network debugging
    strace      # System call tracing
    pstree      # Process tree viewer
    iftop       # Network bandwidth monitoring
    ncdu        # Disk usage analyzer
    bat         # Better cat with syntax highlighting
    ripgrep     # Fast grep alternative
    fd          # Fast find alternative
    jq          # JSON processor
    curl        # HTTP client
    wget        # HTTP downloader
    fzf         # Fuzzy finder for history search and more
  ];
  remoteHomeModule = import ../../home {
    inherit inputs;
    profile = "remote";
    hostname = "hetzner";
  };

  mkCuttlefishBundle = cuttlefish.packages.x86_64-linux.mkCuttlefishFromTarball;

  cuttlefishHost = mkCuttlefishBundle {
    # This tarball is a mirror of Google's "cvd-host_package" bundle for
    # build 14085914 (`aosp_cf_x86_64_only_phone-userdebug`). We originally
    # fetched it with:
    #   $ cvd fetch \
    #       --default_build=aosp_cf_x86_64_only_phone-userdebug \
    #       --default_build_target=aosp_cf_x86_64_only_phone-userdebug \
    #       --system_build=14085914
    # which downloads the dv ".deb" payloads from Google's
    # `gs://android-cuttlefish/` bucket and packs them as
    # `cvd-host_package.tar.gz`. We keep a copy at
    # https://justinmoon.com/s/cuttlefish/ for reproducibility. If that
    # mirror disappears, re-run the `cvd fetch` command above (or rebuild via
    # `pkgs/cuttlefish-from-deb.nix` fed the Google `cuttlefish-base` and
    # `cuttlefish-user` debs) and update the URL + sha256 here.
    url = "https://justinmoon.com/s/cuttlefish/cvd-host_package.tar.gz";
    sha256 = "sha256-owJJyyFlL0Siqd+jpFuyWqZHI59tdaa35iBMa+n/xNE=";
    version = "aosp-14085914";
  };

  cuttlefishFHS = cuttlefish.packages.x86_64-linux.mkCuttlefishFHS {
    cuttlefishBundle = cuttlefishHost;
  };
in
{
  imports = [
    # Include the default modules for a headless system
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.home-manager.nixosModules.home-manager
    # Disk configuration for disko
    ./disk-config.nix
    # Bitcoin node configuration
    ./bitcoin.nix
    # Polkit rules for service management
    ./polkit-rules.nix
    # Blog static site
    ./blog.nix
    # Caddy reverse proxy
    ./caddy.nix
    # Nostr relay (strfry)
    ./strfry.nix
    # Monorepo runner SSH key + known_hosts
    ./monorepo-ssh.nix
    # GitHub SSH key (bypasses YubiKey for git operations)
    ../common/github-ssh.nix
    # Nix binary cache
    ./nix-cache.nix
    # Tailscale mesh VPN (shared auth key)
    ../common/tailscale.nix
    inputs.moq.nixosModules.moq-relay
    ./moq.nix
    # Immich photo server
    ./immich.nix
    # OpenClaw personal knowledge assistant (Marmot)
    ./openclaw.nix
  ];

  nixpkgs.overlays = [
    inputs.moq.overlays.default
    (final: prev: {
      cfctl = cuttlefish.packages.x86_64-linux.cfctl;
    })
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    let name = lib.getName pkg;
    in lib.elem name [
      "1password-cli"
      "_1password-cli"
      "claude-code"
      "cuttlefish-host"
      "cuttlefish-host-aosp-14085914"
    ];

  # Boot configuration for Hetzner
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    # Devices will be populated by disko
  };
  
  boot.kernelModules = [
    "vhost_vsock"
    "vsock"
    "vmw_vsock_virtio_transport"
    "vmw_vsock_virtio_transport_common"
  ];
  
  # Use predictable interface names for Hetzner
  boot.kernelParams = [ "net.ifnames=0" ];
  
  # Basic networking
  networking = {
    hostName = "hetzner";
    useDHCP = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        # 8333 # Bitcoin (added by bitcoin.nix)
      ];
      interfaces.tailscale0 = {
        allowedTCPPorts = [ 22 2283 5000 22000 ];
        allowedUDPPorts = [ 22000 ];
      };
    };
  };

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    openFirewall = false;  # SSH only via Tailscale (port 22 on tailscale0)
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Hetzner-specific Tailscale settings (base config from common/tailscale.nix)
  services.tailscale.useRoutingFeatures = "client";

  # Enable polkit for systemd service management
  security.polkit.enable = true;

  # Enable Chromium SUID sandbox for Playwright E2E tests (monorepo CI)
  # This allows Chromium to run with proper process isolation instead of
  # the unstable --single-process mode that crashes on 2nd+ browser contexts.
  # See: https://github.com/nicx/nixpkgs/blob/master/nixos/modules/security/chromium-suid-sandbox.nix
  security.chromiumSuidSandbox.enable = true;

  # Create a user account
  users.users.justin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "kvm" "cvdnetwork" ]; # Enable 'sudo'
    shell = pkgs.bash;  # Explicitly set bash as the shell
    openssh.authorizedKeys.keys = [
      # 1Password SSH key (backup)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9qcRB7tF1e8M9CX8zoPfNmQgWqvnee0SKASlM0aMlm mail@justinmoon.com"
      # Hetzner dedicated key (no YubiKey needed)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA8Oc7Gtaqck72Y5G92STRSEe/Yl7983H89dMFzMcmI/ hetzner-ssh-key"
      # streambot → Hetzner remote builder key (root/nix-daemon)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5Ed49Poa0vwlJxRzqrbJAlfsYk5/4a6m1EpAI8mq64 streambot-hetzner"
      # streambot openclaw user (for local nixos-rebuild)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKrX6CH4kPJ2xTVElXBIt+OPifzpJmcs+B1R5e3Hk86O openclaw@streambot"
      # YubiKey primary
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOvnevaL7FO+n13yukLu23WNfzRUPzZ2e3X/BBQLieapAAAABHNzaDo= justin@yubikey-primary"
      # YubiKey backup
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMrMVMYKXjA7KuxacP6RexsSfXrkQhwOKwGAfJExDxYZAAAABHNzaDo= justin@yubikey-backup"
    ];
  };

  # Root SSH access (1Password key + monorepo deploy key + YubiKeys)
  users.users.root.openssh.authorizedKeys.keys = [
    # 1Password SSH key (backup)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9qcRB7tF1e8M9CX8zoPfNmQgWqvnee0SKASlM0aMlm mail@justinmoon.com"
    # Hetzner dedicated key (no YubiKey needed)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMQAESH5V93dq/DPAr3rw4XOfKbzc4KKinwl6FPF+Ai hetzner-ssh-key"
    # Monorepo deploy key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGF9RjZoh/bpg50BQKtcqAPIxzSNeAT8NOXMQJ5wXjQN monorepo-deploy-2025-11-30"
    # YubiKey primary
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOvnevaL7FO+n13yukLu23WNfzRUPzZ2e3X/BBQLieapAAAABHNzaDo= justin@yubikey-primary"
    # YubiKey backup
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMrMVMYKXjA7KuxacP6RexsSfXrkQhwOKwGAfJExDxYZAAAABHNzaDo= justin@yubikey-backup"
  ];

  users.users.vibe = {
    isNormalUser = true;
    description = "Isolated remote development account";
    createHome = true;
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # 1Password SSH key (backup)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9qcRB7tF1e8M9CX8zoPfNmQgWqvnee0SKASlM0aMlm mail@justinmoon.com"
      # Hetzner dedicated key (no YubiKey needed)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA8Oc7Gtaqck72Y5G92STRSEe/Yl7983H89dMFzMcmI/ hetzner-ssh-key"
      # YubiKey primary
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOvnevaL7FO+n13yukLu23WNfzRUPzZ2e3X/BBQLieapAAAABHNzaDo= justin@yubikey-primary"
      # YubiKey backup
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMrMVMYKXjA7KuxacP6RexsSfXrkQhwOKwGAfJExDxYZAAAABHNzaDo= justin@yubikey-backup"
    ];
    packages = (with pkgs; [
      tmux
      neovim
      git
      ripgrep
      fd
      nodejs_22
      direnv
    ]) ++ [
      claude-cli
      pkgs.codex
      opencode-cli
    ];
    extraGroups = [ "cvdnetwork" "kvm" ];
  };

  # Allow sudo without password for wheel group (optional, remove if you prefer password)
  security.sudo.wheelNeedsPassword = false;

  # Basic system packages
  environment.systemPackages = basePackages ++ [
    claude-cli
    pkgs.codex
    opencode-cli
    cuttlefishFHS
    pkgs.cfctl
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/cuttlefish 0755 root root - -"
    "d /etc/cuttlefish/instances 0755 root root - -"
    "d /var/lib/cfctl 0770 root cvdnetwork - -"
  ];

  system.activationScripts.populateCuttlefish = ''
    install -d -m 0755 /var/lib/cuttlefish
    if [ ! -d /var/lib/cuttlefish/etc ]; then
      cp -r /opt/cuttlefish/etc /var/lib/cuttlefish/
    fi
    
    # Copy usr/share to writable location (cfctl needs to write QEMU files here)
    # Remove read-only symlink if it exists
    if [ -L /var/lib/cuttlefish/usr ]; then
      rm /var/lib/cuttlefish/usr
    fi
    if [ ! -d /var/lib/cuttlefish/usr/share/qemu ]; then
      mkdir -p /var/lib/cuttlefish/usr/share
      cp -r /opt/cuttlefish/usr/share/qemu /var/lib/cuttlefish/usr/share/
    fi
    
    chown -R justin:cvdnetwork /var/lib/cuttlefish
    chmod -R g+rwX /var/lib/cuttlefish
    install -d -m 0755 /etc/cuttlefish/instances
  '';

  system.activationScripts.cuttlefishUuidPatch = ''
    cfg_file="/var/lib/cuttlefish/android-cuttlefish/base/cvd/cuttlefish/host/libs/config/config_constants.h"
    if [ -f "$cfg_file" ]; then
      ${pkgs.gnused}/bin/sed -i 's/699acfc4-c8c4-11e7-882b-5065f31dc1/699acfc4-c8c4-11e7-882b-5065f31dc/' "$cfg_file"
    fi
  '';

  system.activationScripts.cuttlefishPodmanCleanup = ''
    set -eu
    if command -v podman >/dev/null 2>&1; then
      ids=$(podman ps -a --format '{{.ID}} {{.Image}} {{.Names}}' | awk '/cuttlefish-host/ {print $1}')
      if [ -n "${ids:-}" ]; then
        podman stop $ids || true
        podman rm -f $ids || true
      fi
    fi
  '';

  systemd.services.cuttlefish-preflight = {
    description = "Load vsock modules required for Cuttlefish";
    wantedBy = [ "multi-user.target" ];
    before = [ "cfctl.service" "cuttlefish@stock.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      ${pkgs.kmod}/bin/modprobe vhost_vsock || true
      ${pkgs.kmod}/bin/modprobe vsock || true
      ${pkgs.kmod}/bin/modprobe vmw_vsock_virtio_transport_common || true
      ${pkgs.kmod}/bin/modprobe vmw_vsock_virtio_transport || true
    '';
  };

  systemd.services.cfctl = {
    description = "Cuttlefish controller daemon";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      CFCTL_SOCKET = "/run/cfctl.sock";
      CFCTL_STATE_DIR = "/var/lib/cfctl";
      CFCTL_ETC_DIR = "/etc/cuttlefish/instances";
      CFCTL_DEFAULT_BOOT = "/var/lib/cuttlefish/images/boot.img";
      CFCTL_DEFAULT_INIT_BOOT = "/var/lib/cuttlefish/images/init_boot.img";
      CFCTL_START_TIMEOUT_SECS = "120";
      CFCTL_ADB_TIMEOUT_SECS = "90";
      CFCTL_JOURNAL_LINES = "200";
      CFCTL_ADB_HOST = "127.0.0.1";
      CFCTL_BASE_ADB_PORT = "6520";
      CFCTL_CUTTLEFISH_FHS = "${cuttlefishFHS}/bin/cuttlefish-fhs";
      CFCTL_CUTTLEFISH_INSTANCES_DIR = "/var/lib/cuttlefish/instances";
      CFCTL_CUTTLEFISH_ASSEMBLY_DIR = "/var/lib/cuttlefish/assembly";
      CFCTL_GUEST_USER = "root";
      CFCTL_GUEST_PRIMARY_GROUP = "root";
      CFCTL_GUEST_SUPPLEMENTARY_GROUPS = "cvdnetwork,kvm";
      CFCTL_GUEST_CAPABILITIES = "";
      CFCTL_CUTTLEFISH_SYSTEM_IMAGE_DIR = "/var/lib/cuttlefish/images";
      CFCTL_DISABLE_HOST_GPU = "true";
      RUST_LOG = "debug";
    };
    serviceConfig = {
      ExecStart = "${pkgs.cfctl}/bin/cfctl-daemon";
      Restart = "on-failure";
      RestartSec = 5;
      Group = "cvdnetwork";
      UMask = "0007";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    path = config.environment.systemPackages;
  };

  systemd.services.cuttlefish-prune = {
    description = "Prune stale Cuttlefish instance directories";
    serviceConfig.Type = "oneshot";
    serviceConfig.User = "justin";
    serviceConfig.Group = "cvdnetwork";
    path = [ pkgs.cfctl pkgs.coreutils pkgs.findutils pkgs.systemd ];
    script = ''
      set -euxo pipefail
      cfctl instance prune --max-age-secs $((24 * 60 * 60))
    '';
  };

  systemd.timers.cuttlefish-prune = {
    description = "Daily cleanup of unused Cuttlefish instances";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  users.groups.cvdnetwork = {};

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users = {
      vibe = args@{ pkgs, ... }:
        let
          base = remoteHomeModule args;
        in
          base // {
            home = base.home // {
              username = "vibe";
              homeDirectory = "/home/vibe";
            };
          };
      justin = args@{ pkgs, ... }:
        let
          base = remoteHomeModule args;
        in
          base // {
            home = base.home // {
              username = "justin";
              homeDirectory = "/home/justin";
            };
          };
    };
  };

  # Enable nix flakes
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # Allow justin to control sandbox settings
      trusted-users = [ "root" "justin" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Set your time zone
  time.timeZone = "UTC";

  # Configure bash with fzf integration
  programs.bash = {
    completion.enable = true;
    interactiveShellInit = ''
      # Source fzf key bindings for bash
      if [ -f "${pkgs.fzf}/share/fzf/key-bindings.bash" ]; then
        source "${pkgs.fzf}/share/fzf/key-bindings.bash"
      fi
      
      # Source fzf completion
      if [ -f "${pkgs.fzf}/share/fzf/completion.bash" ]; then
        source "${pkgs.fzf}/share/fzf/completion.bash"
      fi

      # Configure fzf defaults
      export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
      
      # Better history search with preview
      export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
    '';
  };

  programs.fish.enable = true;

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld;
    libraries = with pkgs; [
      stdenv.cc.cc
      stdenv.cc.cc.lib
      glibc
      zlib
      libxml2
      openssl
    ];
  };

  # Nix configuration
  # nix sandbox enabled (default)

  documentation.man.generateCaches = false;

  # Multi-track cuttlefish (disabled - bwrap/ambient caps conflict needs fixing)
  services.cuttlefish = {
    enable = false;
    defaultTrack = "stock";

    tracks.stock = {
      bundle = cuttlefishHost;
    };
  };

  # System state version (don't change this after initial install)
  system.stateVersion = "24.05";
}
