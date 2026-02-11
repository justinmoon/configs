{ config
, lib
, pkgs
, nix-openclaw
, openclawSrc
, openclawMarmotSrc
, ...
}:

let
  gatewayPort = 18789;
  openclawPnpmDepsHash = "sha256-bMIBp+PQnNxKC0BriKo/7VIg+C4TOPWb5PenQ9nSjFA=";
  startOpenclawGateway = pkgs.writeShellScript "openclaw-gateway-start" ''
    set -euo pipefail
    key="$(${pkgs.coreutils}/bin/tr -d '\r\n' < ${config.age.secrets.anthropic-api-key.path} 2>/dev/null || true)"
    if [ -z "$key" ]; then
      echo "ANTHROPIC_API_KEY is empty; update secrets/anthropic-api-key.age and redeploy." >&2
      exit 1
    fi
    token="$(${pkgs.coreutils}/bin/tr -d '\r\n' < ${config.age.secrets.openclaw-gateway-token.path} 2>/dev/null || true)"
    if [ -z "$token" ]; then
      echo "OPENCLAW_GATEWAY_TOKEN is empty; update secrets/openclaw-gateway-token.age and redeploy." >&2
      exit 1
    fi
    export ANTHROPIC_API_KEY="$key"
    export OPENCLAW_GATEWAY_TOKEN="$token"
    exec ${pkgs.openclaw-gateway}/bin/openclaw gateway --port ${toString gatewayPort}
  '';
in
{
  # Build OpenClaw packages from pinned sources (copied from ~/code/infra/nix/hosts/openclaw-prod.nix).
  nixpkgs.overlays = [
    nix-openclaw.overlays.default
    (final: prev: let
      sourceInfo = import "${nix-openclaw}/nix/sources/openclaw-source.nix";
      openclawGateway = final.callPackage "${nix-openclaw}/nix/packages/openclaw-gateway.nix" {
        inherit sourceInfo;
        gatewaySrc = openclawSrc;
        pnpmDepsHash = openclawPnpmDepsHash;
      };

      toolSets = import "${nix-openclaw}/nix/tools/extended.nix" {
        pkgs = final;
        toolNamesOverride = [
          "nodejs_22"
          "pnpm_10"
          "git"
          "curl"
          "jq"
          "ripgrep"
        ];
      };

      openclawBundle = final.callPackage "${nix-openclaw}/nix/packages/openclaw-batteries.nix" {
        openclaw-gateway = openclawGateway;
        openclaw-app = null;
        extendedTools = toolSets.tools;
      };

      marmotRustHarness =
        let
          marmotRustSrc = final.lib.cleanSourceWith {
            src = openclawMarmotSrc;
            filter = path: type:
              let
                p = toString path;
                root = toString openclawMarmotSrc + "/";
              in
                final.lib.any (prefix: final.lib.hasPrefix (root + prefix) p) [
                  "Cargo.toml"
                  "Cargo.lock"
                  "rust-toolchain.toml"
                  "rust_harness"
                ];
          };
        in
          final.rustPlatform.buildRustPackage {
            pname = "marmot-rust-harness";
            version = "0.1.0";
            src = marmotRustSrc;
            nativeBuildInputs = [ final.pkg-config ];
            buildInputs = [ final.openssl ];
            cargoLock = {
              lockFile = marmotRustSrc + "/Cargo.lock";
              outputHashes = {
                "mdk-core-0.5.3" = "sha256-jwQRszjNHiPwLOtnvpkn2aUawc9Da0mTLFO26Wnn5q4=";
                "mdk-sqlite-storage-0.5.1" = "sha256-jwQRszjNHiPwLOtnvpkn2aUawc9Da0mTLFO26Wnn5q4=";
                "mdk-storage-traits-0.5.1" = "sha256-jwQRszjNHiPwLOtnvpkn2aUawc9Da0mTLFO26Wnn5q4=";
                "openmls-0.7.1" = "sha256-dVIqNxTj3fHaeavExwqO5vtEULpMMNIb3GZHmjBJ+24=";
                "openmls_basic_credential-0.4.1" = "sha256-dVIqNxTj3fHaeavExwqO5vtEULpMMNIb3GZHmjBJ+24=";
                "openmls_memory_storage-0.4.1" = "sha256-dVIqNxTj3fHaeavExwqO5vtEULpMMNIb3GZHmjBJ+24=";
                "openmls_rust_crypto-0.4.1" = "sha256-dVIqNxTj3fHaeavExwqO5vtEULpMMNIb3GZHmjBJ+24=";
                "openmls_traits-0.4.1" = "sha256-dVIqNxTj3fHaeavExwqO5vtEULpMMNIb3GZHmjBJ+24=";
              };
            };
            cargoBuildFlags = [ "-p" "rust_harness" ];
          };
    in {
      openclaw-gateway = openclawGateway;
      openclaw = openclawBundle;
      marmot-rust-harness = marmotRustHarness;
    })
  ];

  # Anthropic API key (agenix secret)
  age.secrets.anthropic-api-key = {
    file = ../../secrets/anthropic-api-key.age;
    owner = "openclaw";
    group = "users";
    mode = "0400";
  };
  age.secrets.openclaw-gateway-token = {
    file = ../../secrets/openclaw-gateway-token.age;
    owner = "openclaw";
    group = "users";
    mode = "0400";
  };

  users.users.openclaw = {
    isNormalUser = true;
    createHome = true;
    home = "/home/openclaw";
    extraGroups = [ ];
    openssh.authorizedKeys.keys = config.users.users.justin.openssh.authorizedKeys.keys;
  };

  # Do not open OpenClaw ports on the network. Access via SSH port-forwarding over Tailscale (port 22).

  # Make nix-openclaw HM module available (we still manage openclaw.json ourselves).
  home-manager.sharedModules = [
    nix-openclaw.homeManagerModules.openclaw
  ];

  home-manager.users.openclaw = { pkgs, ... }: {
    home.stateVersion = "24.05";

    programs.openclaw.enable = false;

    home.file.".openclaw/openclaw.json" = {
      force = true;
      text = lib.mkForce (builtins.toJSON {
        agents = {
          defaults = {
            workspace = "/home/openclaw/.openclaw/workspace";
            skipBootstrap = true;
            maxConcurrent = 1;
          };
          list = [
            {
              id = "marmot";
              default = true;
              workspace = "/home/openclaw/.openclaw/workspace";
              identity = {
                name = "Marmot Bot";
                theme = "deterministic";
                emoji = "";
              };
            }
          ];
        };

        gateway = {
          mode = "local";
          port = gatewayPort;
        };

        auth = {
          order = {
            anthropic = [];
          };
        };

        plugins = {
          enabled = true;
          entries = {
            "marmot" = { enabled = true; };
          };
        };

        channels = {
          "marmot" = {
            enabled = true;
            name = "Marmot (Rust)";
            relays = [
              "wss://relay.primal.net"
              "wss://nos.lol"
              "wss://relay.damus.io"
            ];
            groupPolicy = "open";
            autoAcceptWelcomes = true;
            sidecarCmd = "${pkgs.marmot-rust-harness}/bin/rust_harness";
            sidecarArgs = [
              "daemon"
              "--relay" "wss://relay.primal.net"
              "--state-dir" "/home/openclaw/.openclaw/marmot/accounts/default"
              "--allow-pubkey" "11b9a894813efe60d39f8621ae9dc4c6d26de4732411c1cdf4bb15e88898a19c"
              "--allow-pubkey" "2284fc7b932b5dbbdaa2185c76a4e17a2ef928d4a82e29b812986b454b957f8f"
            ];
          };
        };
      });
    };

    home.file.".openclaw/extensions/marmot" = {
      source = openclawMarmotSrc + "/openclaw/extensions/marmot";
      recursive = true;
    };

    home.file.".openclaw/workspace/AGENTS.md" = {
      force = true;
      text = ''
        # Agents

        This workspace is shared by the OpenClaw agent (Marmot Bot) and Pi.
        Both agents can read and write to the slipbox vault at /home/openclaw/slipbox/.
      '';
    };
    home.file.".openclaw/workspace/SOUL.md" = {
      force = true;
      text = ''
        # Soul

        You are Justin's personal knowledge assistant. You help manage a zettelkasten
        (slipbox) of 4000+ notes on history, philosophy, technology, politics, and more.

        You communicate over the Marmot protocol (MLS-encrypted messaging over Nostr).

        Be concise, thoughtful, and direct. When the user shares an idea, help them
        articulate it and save it as a note. When asked to find connections between
        ideas, search broadly and think carefully before responding.
      '';
    };
    home.file.".openclaw/workspace/TOOLS.md" = {
      force = true;
      text = ''
        # Tools

        Standard coding agent tools (bash, read, write, edit) are available.
        See the slipbox skill for API-based note management via slipboxd.
      '';
    };
    home.file.".openclaw/workspace/IDENTITY.md" = {
      force = true;
      text = ''
        # Identity

        - Name: Marmot Bot
        - Role: Personal knowledge assistant
        - Owner: Justin
      '';
    };
    home.file.".openclaw/workspace/USER.md" = {
      force = true;
      text = ''
        # User

        - Name: Justin
        - Interests: History (Rome, Japan, early America), philosophy, technology,
          political economy, Austrian economics, health/nutrition, programming
        - Style: Prefers concise, direct communication. Appreciates atomic notes
          (one idea per note) in the zettelkasten tradition.
      '';
    };
  };

  systemd.services.openclaw-gateway = {
    description = "OpenClaw gateway (OpenClaw user)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      if [ -d /home/openclaw/.openclaw/channels ]; then
        chmod -R go-rwx /home/openclaw/.openclaw/channels || true
      fi
    '';

    serviceConfig = {
      Type = "simple";
      User = "openclaw";
      Group = "users";
      UMask = "0077";
      WorkingDirectory = "/home/openclaw";
      Environment = [
        "HOME=/home/openclaw"
        "OPENCLAW_STATE_DIR=/home/openclaw/.openclaw"
        "CLAWDBOT_STATE_DIR=/home/openclaw/.openclaw"
        "OPENCLAW_CONFIG_PATH=/home/openclaw/.openclaw/openclaw.json"
        "CLAWDBOT_CONFIG_PATH=/home/openclaw/.openclaw/openclaw.json"
        "RELAYS="
      ];

      ExecStart = "${startOpenclawGateway}";
      Restart = "always";
      RestartSec = "2s";
    };
  };

  systemd.services.slipboxd = {
    description = "slipboxd — Slipbox vault web server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    # Avoid failing deploys before the one-time rsync (Step 6) lands the slipboxd source + vault.
    unitConfig = {
      ConditionPathExists = "/home/openclaw/slipboxd/server.ts";
      ConditionPathIsDirectory = "/home/openclaw/slipbox";
    };

    # Defensive hardening: ensure slipboxd never binds to 0.0.0.0 (public/Tailscale).
    preStart = ''
      if [ -f /home/openclaw/slipboxd/server.ts ]; then
        ${pkgs.gnused}/bin/sed -i \
          's/server\\.listen(PORT, \"0\\.0\\.0\\.0\"/server.listen(PORT, \"127.0.0.1\"/' \
          /home/openclaw/slipboxd/server.ts || true
      fi
    '';

    serviceConfig = {
      Type = "simple";
      User = "openclaw";
      Group = "users";
      WorkingDirectory = "/home/openclaw/slipboxd";
      ExecStart = "${pkgs.nodejs_22}/bin/node --experimental-strip-types server.ts --vault /home/openclaw/slipbox --port 7766";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [ "NODE_NO_WARNINGS=1" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/openclaw/.openclaw 0700 openclaw users -"
    "d /home/openclaw/.openclaw/marmot 0700 openclaw users -"
    "d /home/openclaw/.openclaw/marmot/accounts 0700 openclaw users -"
    "d /home/openclaw/.openclaw/marmot/accounts/default 0700 openclaw users -"
    "d /home/openclaw/slipbox 0750 openclaw users -"
    "d /home/openclaw/slipboxd 0750 openclaw users -"
  ];
}
