{inputs, profile ? "desktop", hostname ? "unknown"}: {
  pkgs,
  config,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  isRemote = profile == "remote";
  isAgent = profile == "agent";
  isSprite = profile == "sprite";
  # Agents and remote profiles don't have GUI access
  isHeadless = isRemote || isAgent || isSprite;
  username = if config.home ? username then config.home.username else "justin";
  homeDirectory =
    if config.home ? homeDirectory
    then config.home.homeDirectory
    else if isDarwin
    then "/Users/${username}"
    else "/home/${username}";
  unstable = lib.mkIf (!(isAgent || isSprite)) (import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  });
  
  # Custom Helix with Steel plugin system (DISABLED for now - using nixpkgs helix)
  # helix-steel =
  #   let
  #     steelPkgs = inputs.helix-steel.packages.${pkgs.system};
  #     steelPackage =
  #       if pkgs ? helix-steel then pkgs.helix-steel
  #       else if steelPkgs ? helix
  #       then steelPkgs.helix.overrideAttrs (old: old // {
  #         cargoBuildFeatures = (old.cargoBuildFeatures or [ "git" ]) ++ [ "steel" ];
  #       })
  #       else pkgs.helix;
  #   in steelPackage;
  
  # Config root: for agents, use store paths; for hosts, use live symlinks
  # IMPORTANT: Sprite/agent tarballs are intended to be public artifacts, so we must not
  # accidentally capture sensitive or huge local files (e.g. tracked SSH key handle files,
  # or `node_modules`) into the Nix store closure that gets archived.
  headlessSourceRoot = builtins.path {
    path = inputs.self;
    name = "configs-headless";
    filter = p: _type: let
      root = "${toString inputs.self}/";
      rel = lib.removePrefix root (toString p);
      isSshDir = rel == "home/ssh" || lib.hasPrefix "home/ssh/" rel;
      isNodeModules = lib.hasSuffix "/node_modules" rel || lib.hasInfix "/node_modules/" rel;
    in !(isSshDir || isNodeModules);
  };

  configRoot =
    if isAgent || isSprite
    then "${headlessSourceRoot}/home"
    else if isRemote
    then "${inputs.self}/home"
    else "${homeDirectory}/configs/home";
  
  # For agents, use store paths directly; for hosts, use symlinks for live editing
  mkConfigLink = rel:
    if isAgent || isSprite
    then "${configRoot}/${rel}"
    else config.lib.file.mkOutOfStoreSymlink "${configRoot}/${rel}";
  helixUpstreamLocalPath = "${homeDirectory}/code/helix-config";
  helixUpstreamHasLocal = builtins.pathExists helixUpstreamLocalPath;
  helixUpstreamDirSource =
    if isAgent || isSprite
    then inputs.helix-config
    else if helixUpstreamHasLocal
    then config.lib.file.mkOutOfStoreSymlink helixUpstreamLocalPath
    else inputs.helix-config;
  mkHelixUpstreamLink = rel:
    if isAgent || isSprite
    then builtins.toPath "${inputs.helix-config}/${rel}"
    else if helixUpstreamHasLocal
    then config.lib.file.mkOutOfStoreSymlink "${helixUpstreamLocalPath}/${rel}"
    else builtins.toPath "${inputs.helix-config}/${rel}";
  ngit = pkgs.callPackage ./ngit.nix {};
  npmGlobalDir = "${homeDirectory}/.npm-global";
  spritePackages =
    with pkgs; [
      # Baseline dev UX
      git
      openssh
      curl
      wget
      jq
      ripgrep
      fd
      tmux
      fzf
      zoxide
      direnv
      # Common language tooling (small-ish, frequently needed)
      nodejs_22
    ];
  commonPackages =
    (with pkgs; [
      aria2
      speedtest-cli
      htop
      cloc
      ripgrep
      bun
      deno
      alejandra
      jq
      lua
      rustup
      devenv
      lazygit
      tree
      exercism
      sqlite
      sqlite-utils
      fzf
      gleam
      go
      go-task
      gopls
      nodejs_22
      nodePackages.typescript-language-server
      prettierd
      eslint_d
      yt-dlp
      just
      watchexec
      uv
      bk
      pv
      wdiff
      dioxus-cli
      nostr-rs-relay
      nak
      pkg-config
      devbox
      zoxide
      bat
      sesh
      gum
      glow
      lf
      nnn
      yazi
      zellij
      zls
      llm
      repomix
      nil
      taplo
      rust-script
      wget
      ast-grep
      rclone
      gh
      flyctl
      railway
      wrangler
      ngit
      yubikey-manager
      age-plugin-yubikey
      age
      openssh
      difftastic
      (python312.withPackages (ps:
        with ps; [
          # pdm init wants this
          virtualenv
          openai-whisper
        ]))
      _1password-cli
    ])
    ++ [ inputs.zig.packages.${pkgs.system}."0.15.1" ];
  desktopPackages = with pkgs; [
    nerd-fonts.fira-code
    ollama
  ];
  linuxDesktopPackages = with pkgs; [
    zed-editor
    _1password-gui
    feh
    signal-desktop
  ];
  darwinDesktopPackages = with pkgs; [
    zed-editor
    ngrok
    raycast
    tailscale
    podman
    pinentry_mac  # For FIDO2 SSH askpass GUI prompts
  ];
  remotePackages = with pkgs; [
  ];
in {
  imports = lib.optionals (!isAgent) [
    (import ./modules/services/syncthing.nix {
      inherit inputs profile homeDirectory;
    })
  ];

  # the version we used to install home-manager. this never needs to change.
  home.stateVersion = "24.05";

  nixpkgs = lib.mkIf isHeadless {
    config.allowUnfreePredicate = pkg:
      let name = lib.getName pkg;
      in lib.elem name [ "1password-cli" "_1password-cli" "claude-code" ];
  };

home.sessionVariables = {
    EDITOR = "hx";
    NIX_CONFIG = "warn-dirty = false";
    CLAUDE_CODE_ENABLE_TASKS = "true";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
  };

  # Ensure Nix packages take precedence over cargo-installed ones
  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "$HOME/.local/bin"
    "$HOME/configs/bin"
    "${npmGlobalDir}/bin"
  ];

  home.file =
    {
      # npm global prefix - ensures npm -g installs to ~/.npm-global
      ".npmrc".text = ''
        prefix=${npmGlobalDir}
      '';

      ".config/ghostty/config".source = mkConfigLink "ghostty/config";
      ".config/ghostty/host-overrides".text =
        # Host-specific Ghostty settings
        if hostname == "fw" then ''
          font-size = 16
        ''
        else if hostname == "fusion" then ''
          font-size = 16
        ''
        else if hostname == "mac" then ''
          font-size = 12
          window-decoration = true
        ''
        else ''
          # No host-specific overrides for ${hostname}
        '';
      ".config/agent-tools/checkout-branches.conf".source =
        mkConfigLink "agent-tools/checkout-branches.conf";
      ".config/zed/settings.json".source = mkConfigLink "zed/settings.json";
      ".config/i3/config".source = mkConfigLink "i3/config";
      ".config/helix/config.toml".source = mkConfigLink "helix/config.toml";
      ".config/helix/languages.toml".source = mkConfigLink "helix/languages.toml";
      ".config/helix/init.scm".source = mkConfigLink "helix/init.scm";
      ".config/helix/local".source = mkConfigLink "../helix-plugins";
      ".config/helix/plugins".source = mkConfigLink "../helix-plugins";
      ".config/helix/upstream".source = helixUpstreamDirSource;
      ".config/helix/helix.scm" = {
        source = mkHelixUpstreamLink "helix.scm";
        force = true;
      };
      ".config/helix/focus.scm" = {
        source = mkHelixUpstreamLink "focus.scm";
        force = true;
      };
      ".config/helix/splash.scm" = {
        source = mkHelixUpstreamLink "splash.scm";
        force = true;
      };
      ".config/helix/term.scm" = {
        source = mkHelixUpstreamLink "term.scm";
        force = true;
      };
      ".config/helix/cog.scm" = {
        source = mkHelixUpstreamLink "cog.scm";
        force = true;
      };
      ".config/helix/cogs".source = mkHelixUpstreamLink "cogs";
      ".config/helix/upstream-init.scm" = {
        source = mkHelixUpstreamLink "init.scm";
        force = true;
      };

      ".config/kotlin-language-server/settings.json".text = ''
        {
          "kotlin": {
            "compiler": {
              "jvm": {
                "target": "17"
              }
            },
            "debugAdapter": {
              "enabled": true
            }
          }
        }
      '';
      ".config/lf/lfrc".source = mkConfigLink "lf/lfrc";
    }
    // lib.optionalAttrs (!isSprite) {
      # Keep AI agent configs off Sprites tarballs by default (avoid leaking tokens/credentials).
      ".claude/settings.json".source = mkConfigLink "claude/settings.json";
      ".claude/skills" = {
        source = mkConfigLink "skills";
        force = true;
      };

      # opencode config directory (includes skill -> ../skills symlink)
      ".config/opencode".source = mkConfigLink "opencode";

      # skills for other AI agents
      ".codex/skills" = {
        source = mkConfigLink "skills";
        force = true;
      };
      ".factory/skills" = {
        source = mkConfigLink "skills";
        force = true;
      };
      ".pi/skills" = {
        source = mkConfigLink "skills";
        force = true;
      };
    }
    // lib.optionalAttrs isDarwin {
      ".config/karabiner/karabiner.json".source = mkConfigLink "karabiner.json";
    };

  home.packages =
    (if isSprite then spritePackages else commonPackages)
    ++ lib.optionals (!isHeadless) desktopPackages
    ++ lib.optionals (!isHeadless && isLinux) linuxDesktopPackages
    ++ lib.optionals (!isHeadless && isDarwin) darwinDesktopPackages
    ++ lib.optionals isRemote remotePackages
    ++ lib.optionals isAgent [
      # Agent-specific packages
      pkgs.nix
      pkgs.cacert
      # FIXME: would prefer to use `just update-agents` (npm install) for latest
      # versions, but mounting host npm-global into container was a rabbit hole
      pkgs.claude-code
      pkgs.codex
    ]
    ++ lib.optionals (!(isAgent || isSprite)) [
      inputs.cg.packages.${pkgs.system}.default
      (pkgs.writeShellScriptBin "yeet" ''
        export YEET_ORIGINAL_PWD="$(pwd)"
        YEET_DIR="${if isDarwin then "$HOME/code/yeet" else "$HOME/yeet"}"
        cd "$YEET_DIR" && exec ${pkgs.bun}/bin/bun run src/index.ts "$@"
      '')
    ];

  # Ensure npm global prefix exists to avoid npx ENOENT on ~/.npm-global/lib
  home.activation.ensureNpmGlobalDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${npmGlobalDir}/bin" "${npmGlobalDir}/lib"
  '';

  # Global bun packages - updated on activation for latest versions.
  # Disabled for Sprite/agent profiles to keep env reproducible and avoid public-tarball surprises.
  home.activation.ensureBunGlobalPackages = lib.mkIf (!(isAgent || isSprite)) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.bun}/bin/bun add -g \
      puppeteer-core \
      @anthropic-ai/claude-code \
      @openai/codex \
      opencode-ai \
      agent-browser \
      @mariozechner/pi-coding-agent
  '');

  # Factory Droid CLI: install if missing, skip if already present (~2 min download).
  # To force update: rm ~/.local/bin/droid && just switch mac
  # Wrapped in subshell to avoid PATH leak affecting subsequent activation scripts
  home.activation.ensureDroidCli = lib.mkIf (!(isAgent || isSprite)) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -x ~/.local/bin/droid ]; then
      echo "Droid CLI already installed, skipping (rm ~/.local/bin/droid to force update)"
    else
      (
        export PATH="${pkgs.curl}/bin:${pkgs.gawk}/bin:${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:/usr/bin:$PATH"
        rm -f ~/.local/bin/droid ~/.local/bin/rg 2>/dev/null || true
        ${pkgs.curl}/bin/curl -fsSL https://app.factory.ai/cli | ${pkgs.bash}/bin/bash
      )
    fi
  '');

  # Install opencode tool dependencies
  home.activation.installOpencodeToolDeps = lib.mkIf (!isRemote && !(isAgent || isSprite)) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ~/.config/opencode/package.json ] && [ -w ~/.config/opencode ]; then
      cd ~/.config/opencode && ${pkgs.bun}/bin/bun install --silent
    fi
  '');
  targets.darwin.linkApps.enable = false;



  # Decrypt local VM SSH key on first setup (skips if already present)
  # Only runs on personal mac - VMs just need the public key in authorized_keys
  home.activation.decryptLocalVmKey = lib.mkIf (hostname == "mac" && !isAgent) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f ~/.ssh/id_ed25519_local ] || [ ! -s ~/.ssh/id_ed25519_local ]; then
      echo "Decrypting local VM SSH key (requires YubiKey)..."
      export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
      if ${pkgs.age}/bin/age -d -i ${configRoot}/../yubikeys/keys.txt ${configRoot}/../secrets/local-vm-key.age > ~/.ssh/id_ed25519_local.tmp 2>/dev/null && [ -s ~/.ssh/id_ed25519_local.tmp ]; then
        chmod 600 ~/.ssh/id_ed25519_local.tmp
        mv ~/.ssh/id_ed25519_local.tmp ~/.ssh/id_ed25519_local
        echo "Local VM SSH key installed."
      else
        rm -f ~/.ssh/id_ed25519_local.tmp
        echo "Warning: Could not decrypt local VM key. Run 'just switch' again with YubiKey connected."
      fi
    fi
  '');

  # Decrypt GitHub SSH key (bypasses YubiKey for git operations)
  # Shared across all hosts via age-encrypted secret
  home.activation.decryptGithubKey = lib.mkIf (hostname == "mac" && !isAgent) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f ~/.ssh/id_ed25519_github ] || [ ! -s ~/.ssh/id_ed25519_github ]; then
      echo "Decrypting GitHub SSH key (requires YubiKey)..."
      export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
      if ${pkgs.age}/bin/age -d -i ${configRoot}/../yubikeys/keys.txt ${configRoot}/../secrets/github-ssh-key.age > ~/.ssh/id_ed25519_github.tmp 2>/dev/null && [ -s ~/.ssh/id_ed25519_github.tmp ]; then
        chmod 600 ~/.ssh/id_ed25519_github.tmp
        mv ~/.ssh/id_ed25519_github.tmp ~/.ssh/id_ed25519_github
        echo "GitHub SSH key installed."
      else
        rm -f ~/.ssh/id_ed25519_github.tmp
        echo "Warning: Could not decrypt GitHub key. Run 'just switch' again with YubiKey connected."
      fi
    fi
  '');

  # Decrypt Hetzner SSH key (bypasses YubiKey for server access)
  home.activation.decryptHetznerKey = lib.mkIf (hostname == "mac" && !isAgent) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f ~/.ssh/id_ed25519_hetzner ] || [ ! -s ~/.ssh/id_ed25519_hetzner ]; then
      echo "Decrypting Hetzner SSH key (requires YubiKey)..."
      export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
      if ${pkgs.age}/bin/age -d -i ${configRoot}/../yubikeys/keys.txt ${configRoot}/../secrets/hetzner-ssh-key.age > ~/.ssh/id_ed25519_hetzner.tmp 2>/dev/null && [ -s ~/.ssh/id_ed25519_hetzner.tmp ]; then
        chmod 600 ~/.ssh/id_ed25519_hetzner.tmp
        mv ~/.ssh/id_ed25519_hetzner.tmp ~/.ssh/id_ed25519_hetzner
        echo "Hetzner SSH key installed."
      else
        rm -f ~/.ssh/id_ed25519_hetzner.tmp
        echo "Warning: Could not decrypt Hetzner key. Run 'just switch' again with YubiKey connected."
      fi
    fi
  '');

  # SSH sockets directory for connection multiplexing
  home.activation.ensureSshSockets = lib.mkIf (hostname == "mac" && !isAgent) (lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ~/.ssh/sockets
    chmod 700 ~/.ssh/sockets
  '');

  programs.git = {
    enable = true;
    settings = {
      user.name = "Justin Moon";
      user.email = "mail@justinmoon.com";
      init.defaultBranch = "master";
      push.default = "current";
      pull.rebase = true;
      # Reuse recorded resolution - automatically resolves previously seen merge conflicts
      rerere.enabled = true;
      # Git aliases (difftastic alternatives)
      alias = {
        difft = "difftool";
        dft = "difftool";
        logt = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff \${@}; }; f";
        showt = "!f() { GIT_EXTERNAL_DIFF=difft git show --ext-diff \${@}; }; f";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "Nord";
    };
  };

  programs = {
    chromium = lib.mkIf (isLinux && !isHeadless) {
      enable = true;
      package = pkgs.chromium;
      extensions = [
        # 1Password
        # https://chromewebstore.google.com/detail/1password-%E2%80%93-password-mana/aeblfdkhhhdcdjpifhhbdiojplfjncoa
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"

        # uBlock Origin
        # https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm
        "cjpalhdlnbpafiamejdnhcphjbkeiagm"

        # nos2x - Nostr signer
        # https://chromewebstore.google.com/detail/nos2x/kpgefcfmnafjgpblomihpgmejjdanjjp
        "kpgefcfmnafjgpblomihpgmejjdanjjp"

        # Nord theme
        "abehfkkfjlplnjadfcjiflnejblfmmpj"
      ];
    };

    brave = lib.mkIf (!isHeadless) {
      enable = true;
      extensions = [
        # 1Password
        # https://chromewebstore.google.com/detail/1password-%E2%80%93-password-mana/aeblfdkhhhdcdjpifhhbdiojplfjncoa
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"

        # uBlock Origin
        # https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm
        "cjpalhdlnbpafiamejdnhcphjbkeiagm"

        # nos2x - Nostr signer
        # https://chromewebstore.google.com/detail/nos2x/kpgefcfmnafjgpblomihpgmejjdanjjp
        "kpgefcfmnafjgpblomihpgmejjdanjjp"
      ];
      commandLineArgs = [
        # Disable Leo AI and VPN
        "--disable-features=AIChat,BraveVPN"
      ];
    };

    firefox = lib.mkIf (!isHeadless && isDarwin) {
      enable = true;
      profiles.justin = {
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          # 1Password password manager
          # https://addons.mozilla.org/en-US/firefox/addon/1password-x-password-manager/
          onepassword-password-manager

          # uBlock Origin ad blocker
          # https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/
          ublock-origin

          # nos2x-fox - Nostr signer for Firefox (custom build)
          # https://addons.mozilla.org/en-US/firefox/addon/nos2x-fox/
          (pkgs.callPackage ./firefox-addons/nos2x-fox.nix {
            buildFirefoxXpiAddon = pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon;
          })
        ];
        settings = {
          # Enable extension installation from addons.mozilla.org
          "xpinstall.signatures.required" = false;

          # Disable Firefox home page ads and sponsored content
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.topsites" = false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;

          # Disable telemetry
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.archive.enabled" = false;
        };
      };
    };
  };

  # SSH config for all hosts (including headless/remote)
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # GitHub: use dedicated key to bypass YubiKey requirement (all hosts)
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = ["~/.ssh/id_ed25519_github"];
        identitiesOnly = true;
      };
    } // lib.optionalAttrs isRemote {
      # Remote hosts (Hetzner) use deploy key for monorepo servers
      monorepo-prod = {
        hostname = "5.161.204.22";
        user = "root";
        identityFile = ["~/.ssh/monorepo_deploy"];
        identitiesOnly = true;
      };
      monorepo-staging = {
        hostname = "178.156.146.77";
        user = "root";
        identityFile = ["~/.ssh/monorepo_deploy"];
        identitiesOnly = true;
      };
    } // lib.optionalAttrs (!isHeadless) {
      # Desktop-only SSH configs below
      # Global SSH options (no identity files - those are per-host)
      "*" = lib.mkIf (hostname == "mac") {
        extraOptions = {
          # Use our custom FIDO2-capable agent, not macOS default
          IdentityAgent = "~/.ssh/agent-fido.sock";
          # Connection multiplexing: reuse connections to reduce YubiKey touches
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/%r@%h-%p";
          ControlPersist = "600";  # Keep connection open 10 minutes
        };
      };
      hetzner = {
        hostname = "100.73.239.5";  # Tailscale IP (SSH is Tailscale-only)
        identityFile = ["~/.ssh/id_ed25519_hetzner"];
        identitiesOnly = true;
      };
      # Production servers using YubiKey
      sled-prod = {
        hostname = "5.78.118.108";
        user = "root";
        identitiesOnly = true;
        identityFile = ["~/.ssh/id_ed25519"];
      };
      monorepo-prod = {
        hostname = "5.161.204.22";
        user = "root";
        identityFile = ["~/.ssh/id_ed25519"];
        identitiesOnly = true;
        extraOptions = {
          UserKnownHostsFile = "~/.ssh/known_hosts_monorepo";
        };
      };
      monorepo-staging = {
        hostname = "178.156.146.77";
        user = "root";
        identityFile = ["~/.ssh/id_ed25519"];
        identitiesOnly = true;
        extraOptions = {
          UserKnownHostsFile = "~/.ssh/known_hosts_monorepo";
        };
      };
      orb = {
        hostname = "orb.orb.local";
        user = "justin";
        identityFile = ["~/.ssh/id_ed25519_local"];
        identitiesOnly = true;
        forwardAgent = true;
      };
      fusion = {
        hostname = "fusion.local";
        user = "justin";
        addressFamily = "inet";  # Force IPv4 - IPv6 link-local doesn't work over VMware NAT
        identityFile = ["~/.ssh/id_ed25519_local"];
        identitiesOnly = true;
        forwardAgent = true;
      };
      utm = {
        hostname = "192.168.64.4";
        user = "justin";
        identityFile = ["~/.ssh/id_ed25519_local"];
        identitiesOnly = true;
        forwardAgent = true;
      };
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit =
      if isAgent || isSprite
      then ''
        # Agent fish config - source from store
        source ${configRoot}/config.fish
      ''
      else ''
        if test -f ${configRoot}/config.fish
          source ${configRoot}/config.fish
        end
      '';
  };

  programs.tmux = {
    enable = true;
    plugins = [
      pkgs.tmuxPlugins.nord
      pkgs.tmuxPlugins.resurrect
      pkgs.tmuxPlugins.continuum
    ];
    extraConfig =
      if isAgent || isSprite
      then builtins.readFile "${configRoot}/tmux.conf"
      else ''
        source-file ${configRoot}/tmux.conf
      '';
  };

  # Helix editor (using standard nixpkgs version for now)
  programs.helix = {
    enable = true;
    # package = helix-steel;  # DISABLED - using default nixpkgs helix
  };

  programs.starship = {
    enable = true;
    settings = {
      # prompt gets messed up in Orbstack without this
      container = {disabled = true;};
      # Disable Bun version detection to avoid timeout warnings
      bun = {disabled = true;};
      # Increase timeout for commands that need it
      command_timeout = 1000;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      global.hide_env_diff = true;
      whitelist.prefix = [ "~/code/monorepo" ];
    };
  };


  programs.i3status = lib.mkIf (isLinux && !isHeadless) {
    enable = true;
    general = {
      colors = true;
      color_good = "#81a1c1";
      color_degraded = "#fafe7c";
      color_bad = "#ff7770";
    };
  };

  # Symlink GUI apps to ~/Applications for Spotlight on macOS
}
