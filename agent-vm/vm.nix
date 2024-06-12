# MicroVM NixOS configuration for agent VMs
# This module is imported by the microvm.nix nixosModules.microvm
{ config, pkgs, lib, ... }:

{
  # MicroVM settings
  microvm = {
    # Force QEMU - vfkit doesn't support port forwarding via NAT
    # QEMU works on both Linux (KVM) and macOS (HVF)
    hypervisor = "qemu";

    # Resource allocation
    vcpu = 2;
    mem = 1024;  # 1GB RAM

    # Shared directory for session data
    # Uses symlink indirection: /tmp/agent-vm-session -> actual session dir
    # This allows runtime session selection without rebuilding
    shares = [{
      # Use 9p for broader compatibility (works on macOS without virtiofsd)
      proto = "9p";
      tag = "session";
      source = "/tmp/agent-vm-session";  # Symlinked at spawn time
      mountPoint = "/session";
    }];

    # User-mode networking for SSH access
    # Note: We don't use forwardPorts here - we handle it via extraArgsScript
    # to allow dynamic port assignment at runtime
    interfaces = [{
      type = "user";
      id = "eth0";
      mac = "02:00:00:00:00:01";
    }];

    # Dynamic port forwarding via extraArgsScript
    # The AGENT_SSH_PORT env var is set by agent-spawn before launching
    extraArgsScript = toString (pkgs.writeShellScript "agent-vm-args" ''
      PORT=''${AGENT_SSH_PORT:-2222}
      echo "-netdev user,id=eth0,hostfwd=tcp::$PORT-:22"
    '');

    # Use a writable overlay for the root filesystem
    writableStoreOverlay = "/nix/.rw-store";

    # Socket path for the VM runner
    socket = "control.socket";
  };

  # Boot configuration
  boot.kernelParams = [ "console=ttyS0" ];

  # Networking
  networking = {
    hostName = "agent";
    # Use DHCP from user-mode networking
    useDHCP = true;
    firewall.enable = false;
  };

  # Packages available in the VM
  environment.systemPackages = with pkgs; [
    opencode
    git
    tmux
    jq
    curl
    vim
    # Development essentials
    coreutils
    gnugrep
    gnused
    findutils
  ];

  # SSH server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Agent user
  users.users.agent = {
    isNormalUser = true;
    password = "agent";
    extraGroups = [ "wheel" ];
    home = "/home/agent";
    createHome = true;
  };

  # Allow agent to sudo without password (for convenience in dev)
  security.sudo.wheelNeedsPassword = false;

  # Git configuration for the agent
  environment.etc."gitconfig".text = ''
    [user]
      name = Agent
      email = agent@localhost
    [init]
      defaultBranch = main
    [safe]
      directory = /session/repo
  '';

  # Systemd service to run opencode in tmux
  systemd.services.agent = {
    description = "OpenCode Agent Session";
    after = [ "network.target" "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];

    # Wait for the session directory to be mounted
    unitConfig = {
      RequiresMountsFor = "/session";
      # Don't restart on failure (let user investigate)
      StartLimitIntervalSec = 0;
    };

    environment = {
      # opencode uses XDG directories for storage
      XDG_DATA_HOME = "/session";
      XDG_CONFIG_HOME = "/session";
      XDG_STATE_HOME = "/session";
      XDG_CACHE_HOME = "/session/cache";
      HOME = "/home/agent";
      # ANTHROPIC_API_KEY is injected at runtime via EnvironmentFile
    };

    serviceConfig = {
      Type = "forking";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/session/repo";
      # Read API key from environment file (created by agent-spawn)
      EnvironmentFile = "-/session/env";
      # Start tmux with opencode
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = pkgs.writeShellScript "start-agent" ''
        # Ensure we're in the right directory
        cd /session/repo || exit 1

        # Read the prompt
        PROMPT=""
        if [ -f /session/prompt.txt ]; then
          PROMPT=$(cat /session/prompt.txt)
        fi

        # Export all environment variables (including ANTHROPIC_API_KEY from EnvironmentFile)
        # tmux new-session -d starts a fresh shell, so we need to pass env vars explicitly
        export ANTHROPIC_API_KEY
        export XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME HOME

        # Start tmux session with opencode, passing environment via -e
        # The env vars are inherited by tmux but need to be set in the tmux environment
        ${pkgs.tmux}/bin/tmux new-session -d -s agent \; \
          set-environment ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY" \; \
          set-environment XDG_DATA_HOME "$XDG_DATA_HOME" \; \
          set-environment XDG_CONFIG_HOME "$XDG_CONFIG_HOME" \; \
          set-environment XDG_STATE_HOME "$XDG_STATE_HOME" \; \
          set-environment XDG_CACHE_HOME "$XDG_CACHE_HOME" \; \
          set-environment HOME "$HOME" \; \
          send-keys "cd /session/repo && ${pkgs.opencode}/bin/opencode" Enter
      '';
      ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t agent";
      RemainAfterExit = true;
      Restart = "no";
    };
  };

  # Mount the session directory via 9p
  fileSystems."/session" = {
    device = "session";
    fsType = "9p";
    options = [ "trans=virtio" "version=9p2000.L" "msize=104857600" ];
  };

  # System settings
  system.stateVersion = "24.11";

  # Disable unnecessary services for minimal footprint
  documentation.enable = false;
  programs.command-not-found.enable = false;

  # Timezone
  time.timeZone = "UTC";
}
