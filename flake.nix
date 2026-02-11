{
  description = "Justin's Nix configs";

  nixConfig = {
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    zig.url = "github:mitchellh/zig-overlay";
    moq.url = "github:kixelated/moq";
    moq.inputs.nixpkgs.follows = "nixpkgs";
    moq.inputs.flake-utils.follows = "flake-utils";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # OpenClaw gateway + Marmot (personal knowledge assistant)
    nix-openclaw = {
      url = "github:justinmoon/nix-openclaw/marmot-ts-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    openclaw-src = {
      url = "github:justinmoon/openclaw/4dc532e2fd1a1228219bf3d538d43a36f9259a41";
      flake = false;
    };
    openclaw-marmot-src = {
      url = "github:justinmoon/openclaw-marmot";
      flake = false;
    };
    # Cuttlefish packages and modules
    cuttlefish.url = "github:justinmoon/fundroid?dir=cuttlefish&ref=cf-pid1-logging-codex";
    cuttlefish.inputs.nixpkgs.follows = "nixpkgs";
    # Context Graph - TypeScript code ingestion into Kuzu graph DB
    cg = {
      url = "github:justinmoon/context-graph";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crank = {
      url = "github:justinmoon/crank";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Agent VM - ephemeral microvms for isolated coding tasks
    agent-vm = {
      url = "path:./agent-vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    nixpkgs-master,
    home-manager,
    nur,
    flake-utils,
    disko,
    cuttlefish,
    ...
  }: let
    username = "justin";

    # claude-code and codex installed via npm (have auto-update)
    # To add more bleeding-edge packages from nixpkgs master:
    # customPackagesOverlay = final: prev: let
    #   masterPkgs = import nixpkgs-master {
    #     system = final.stdenv.hostPlatform.system;
    #     config.allowUnfree = true;
    #   };
    # in { somePackage = masterPkgs.somePackage; };
    customPackagesOverlay = final: prev: {};
    # Import the flake-utils
    utils = flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          customPackagesOverlay
        ];
      };
    in {
      # Define the default shell environment
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.just
          pkgs.nixos-rebuild
          pkgs.nixos-anywhere
        ];
      };

      devShells.blog = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.bun
        ];
        shellHook = ''
          echo "Blog dev environment loaded (Bun $(bun --version))"
        '';
      };

      packages.blog = pkgs.callPackage ./blog/package.nix {};

      # gogcli - Google Workspace CLI
      packages.gog = let
        version = "0.9.0";
        hashes = {
          "x86_64-linux" = "sha256-KCGfSlGjHixPV81bCT/zA6WUN4S5bDtH5t2HezaFEfU=";
          "aarch64-linux" = "sha256-Z6T7l0w0FWXARvsOH2E/glqm8JSpkEtrxGRGQJdHQfc=";
          "x86_64-darwin" = "sha256-qJgF23Y4PjMDi/xAd3o/LjjL4vEEhGloWyVQdGmD4DI=";
          "aarch64-darwin" = "sha256-MyG0h5BwSQ9elXF/DHDTdPRqmB1JMEDELitNvW9iUys=";
        };
        platforms = {
          "x86_64-linux" = "linux_amd64";
          "aarch64-linux" = "linux_arm64";
          "x86_64-darwin" = "darwin_amd64";
          "aarch64-darwin" = "darwin_arm64";
        };
      in pkgs.stdenv.mkDerivation {
        pname = "gogcli";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/steipete/gogcli/releases/download/v${version}/gogcli_${version}_${platforms.${system}}.tar.gz";
          hash = hashes.${system};
        };
        sourceRoot = ".";
        installPhase = ''
          mkdir -p $out/bin
          cp gog $out/bin/
          chmod +x $out/bin/gog
        '';
        dontFixup = pkgs.stdenv.isDarwin;
      };

      # agent-browser - Browser automation for AI agents
      packages.agent-browser = let
        version = "0.8.5";
        hashes = {
          "x86_64-linux" = "sha256-/QIVN2fOY+Uz0Xiho2WeQUG4q633gZNRfDnsBbSA70M=";
          "aarch64-linux" = "sha256-JIsOtaok+MJiLg8HKjkRNXEy259NgJrVWmB0cDQ9EPk=";
          "x86_64-darwin" = "sha256-Tcb8BiclUSbDHtN1p2DzyKLXxNWpVUkjmmwxetpjKh4=";
          "aarch64-darwin" = "sha256-V61P5Tgd71dh9Es1DrMoNlzfIplFrOWtOruWKWXTPXc=";
        };
        binaries = {
          "x86_64-linux" = "agent-browser-linux-x64";
          "aarch64-linux" = "agent-browser-linux-arm64";
          "x86_64-darwin" = "agent-browser-darwin-x64";
          "aarch64-darwin" = "agent-browser-darwin-arm64";
        };
      in pkgs.stdenv.mkDerivation {
        pname = "agent-browser";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/${binaries.${system}}";
          hash = hashes.${system};
        };
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/agent-browser
          chmod +x $out/bin/agent-browser
        '';
        dontFixup = pkgs.stdenv.isDarwin;
      };

      # Fly Sprites: Nix store tarball to extract at / (home-manager-based)
      # Build with: nix build ~/configs#packages.x86_64-linux.cockpit-sprite-env-tarball
      packages.cockpit-sprite-env-tarball = import ./nix/cockpit-sprite-env-tarball.nix {
        inherit inputs;
      };

      apps.pre-merge = {
        type = "app";
        program = toString (pkgs.writeShellScript "pre-merge-check" ''
          set -e
          echo "Running pre-merge checks for configs..."
          # Just verify flake is valid
          ${pkgs.nix}/bin/nix flake show --no-warn-dirty > /dev/null
          echo "Pre-merge checks passed!"
        '');
      };

      apps.post-merge = {
        type = "app";
        program = toString (pkgs.writeShellScript "post-merge-deploy" ''
          export PATH="${pkgs.lib.makeBinPath [ pkgs.git pkgs.nix pkgs.coreutils pkgs.bash pkgs.rsync pkgs.openssh pkgs.systemd ]}"
          exec ${pkgs.bash}/bin/bash ${./scripts/post-merge-deploy.sh} "$@"
        '');
      };

      devShells.aosp = let
        repoTool = pkgs.stdenvNoCC.mkDerivation rec {
          pname = "repo";
          version = "2.46";

          src = pkgs.fetchurl {
            url = "https://storage.googleapis.com/git-repo-downloads/repo";
            sha256 = "sha256-bLopTWIYu9ShUAWYIHs5ecdSx6EirvlCnk1/72iIM7U=";
          };

          dontUnpack = true;
          dontBuild = true;

          installPhase = ''
            install -Dm755 "$src" "$out/bin/repo"
          '';
        };
      in pkgs.mkShell {
        shell = pkgs.bashInteractive;
        packages = with pkgs; [
          repoTool
          git
          git-lfs
          python311
          python311Packages.virtualenv
          openjdk17_headless
          ccache
          ninja
          cmake
          gnumake
          gcc
          gperf
          flex
          bison
          pkg-config
          libxml2
          libxslt
          unzip
          zip
          zstd
          lzop
          openssl
          rsync
          curl
          bc
          which
          perl
          file
          nasm
          gawk
          coreutils
          diffutils
          bashInteractive
        ] ++ (with pkgs.xorg; [
          libX11
          libXext
          libXrender
          libXrandr
          libXi
        ]);
        shellHook = ''
          export USE_CCACHE=1
          if [ -d /var/lib/aosp/ccache ]; then
            export CCACHE_DIR=/var/lib/aosp/ccache
          else
            export CCACHE_DIR="''${CCACHE_DIR:-$PWD/.ccache}"
          fi
          mkdir -p "$CCACHE_DIR"
        '';
      };

    });
  in ({
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/mac
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = [
              nur.overlays.default
              customPackagesOverlay
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home {
              inputs = inputs;
              hostname = "mac";
            };
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      # not working for some reason
      # packages.aarch64-darwin.ai-shell = import ./home/ai-shell.nix {
      # inherit (nixpkgs.legacyPackages.aarch64-darwin) lib pkgs;
      # };

      # Agent home configurations for capsule containers
      # Build with: nix build .#homeConfigurations.agent-x86_64.activationPackage
      # or: nix build .#homeConfigurations.agent-aarch64.activationPackage
      homeConfigurations.agent-x86_64 = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          {
            home.username = "agent";
            home.homeDirectory = "/home/agent";
          }
          (import ./home {
            inputs = inputs;
            profile = "agent";
            hostname = "container";
          })
        ];
        extraSpecialArgs = {
          inherit inputs;
        };
      };

      # Sprite home configuration (x86_64-linux)
      # Build activation: nix build .#homeConfigurations.sprite-x86_64.activationPackage
      homeConfigurations.sprite-x86_64 = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          {
            home.username = "sprite";
            home.homeDirectory = "/home/sprite";
          }
          (import ./home {
            inputs = inputs;
            profile = "sprite";
            hostname = "container";
          })
        ];
        extraSpecialArgs = {
          inherit inputs;
        };
      };

      homeConfigurations.agent-aarch64 = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        modules = [
          {
            home.username = "agent";
            home.homeDirectory = "/home/agent";
          }
          (import ./home {
            inputs = inputs;
            profile = "agent";
            hostname = "container";
          })
        ];
        extraSpecialArgs = {
          inherit inputs;
        };
      };

      nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          self.nixosModules.cuttlefish
          inputs.agenix.nixosModules.default
          ./hosts/hetzner/configuration.nix
          {
            nixpkgs.overlays = [ customPackagesOverlay ];
            services.blog = {
              enable = true;
              package = self.packages.x86_64-linux.blog;
            };
          }
        ];
        specialArgs = {
          inherit inputs;
          inherit cuttlefish;
          nix-openclaw = inputs."nix-openclaw";
          openclawSrc = inputs."openclaw-src";
          openclawMarmotSrc = inputs."openclaw-marmot-src";
        };
      };

      # Hetzner sandbox: lightweight ephemeral VM for coding
      # Usage: nixos-rebuild switch --flake ~/configs#sandbox
      # Bootstrap: nix run github:nix-community/nixos-anywhere -- --flake ~/configs#sandbox --target-host root@<ip>
      nixosConfigurations.sandbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          ./hosts/sandbox/configuration.nix
          {
            nixpkgs.overlays = [ customPackagesOverlay ];
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      # Modal sandbox configuration for remote coding agents
      # Build home-manager activation: nix build .#homeConfigurations.modal.activationPackage
      homeConfigurations.modal = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          {
            home.username = "root";
            home.homeDirectory = "/root";
          }
          (import ./home {
            inputs = inputs;
            profile = "agent";
            hostname = "modal";
          })
        ];
        extraSpecialArgs = {
          inherit inputs;
        };
      };

      nixosConfigurations.fusion = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.agenix.nixosModules.default
          ./hosts/fusion/configuration.nix
          {
            nixpkgs.overlays = [
              nur.overlays.default
              customPackagesOverlay
            ];
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      nixosConfigurations.utm = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.agenix.nixosModules.default
          ./hosts/utm/configuration.nix
          {
            nixpkgs.overlays = [
              nur.overlays.default
              customPackagesOverlay
            ];
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      nixosConfigurations.orb = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.agenix.nixosModules.default
          ./hosts/orb/configuration.nix
          {
            nixpkgs.overlays = [
              nur.overlays.default
              customPackagesOverlay
            ];
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      nixosConfigurations.fw = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.agenix.nixosModules.default
          ./hosts/fw/configuration.nix
          {
            nixpkgs.overlays = [
              nur.overlays.default
              customPackagesOverlay
            ];
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."mac".pkgs;

      nixosModules.cuttlefish = cuttlefish.nixosModules.cuttlefish;
    }
    // utils);
}
