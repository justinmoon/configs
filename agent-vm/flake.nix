{
  description = "Ephemeral microvms running opencode for isolated coding tasks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm, ... }:
    let
      # Systems where the host tools run (macOS for spawning, Linux for running VMs)
      hostSystems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      # Systems for the VM itself (always Linux)
      vmSystems = [ "x86_64-linux" "aarch64-linux" ];

      forAllHostSystems = nixpkgs.lib.genAttrs hostSystems;
      forAllVmSystems = nixpkgs.lib.genAttrs vmSystems;
    in {
      # NixOS configurations for the agent VM
      nixosConfigurations = forAllVmSystems (system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ./vm.nix
          ];
        }
      );

      # Packages: the VM runner and CLI tools
      packages = forAllHostSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isDarwin = pkgs.stdenv.isDarwin;

          # Determine target VM system based on host
          vmSystem = if system == "aarch64-darwin" || system == "aarch64-linux"
                     then "aarch64-linux"
                     else "x86_64-linux";

          # Get VM config
          vmConfig = self.nixosConfigurations.${vmSystem}.config;

          # For Linux hosts, use the bundled runner
          # For Darwin hosts, create a custom runner with macOS QEMU
          vmRunner = if isDarwin then
            let
              # Use macOS QEMU
              qemu = pkgs.qemu;
              # Get the VM artifacts from the NixOS config
              kernel = vmConfig.microvm.kernel;
              initrd = vmConfig.microvm.initrdPath;
              storeDisk = vmConfig.microvm.storeDisk;
              toplevel = vmConfig.system.build.toplevel;
              closureInfo = pkgs.closureInfo { rootPaths = [ toplevel ]; };
              # Build our own runner script for macOS
            in pkgs.writeShellScriptBin "microvm-run" ''
              set -euo pipefail

              # Get dynamic port from environment
              PORT=''${AGENT_SSH_PORT:-2222}

              # Session directory (symlinked at /tmp/agent-vm-session)
              SESSION_DIR="/tmp/agent-vm-session"

              exec ${qemu}/bin/qemu-system-aarch64 \
                -name agent \
                -M virt,accel=hvf:tcg \
                -cpu host \
                -m 1024 \
                -smp 2 \
                -nographic \
                -nodefaults \
                -no-reboot \
                -kernel ${kernel}/Image \
                -initrd ${initrd} \
                -append "console=ttyAMA0 reboot=t panic=-1 root=fstab loglevel=4 init=${toplevel}/init regInfo=${closureInfo}/registration" \
                -drive "id=store,format=raw,read-only=on,file=${storeDisk},if=none" \
                -device "virtio-blk-pci,drive=store" \
                -fsdev "local,id=fs0,path=$SESSION_DIR,security_model=mapped-xattr" \
                -device "virtio-9p-pci,fsdev=fs0,mount_tag=session" \
                -netdev "user,id=eth0,hostfwd=tcp::$PORT-:22" \
                -device "virtio-net-pci,netdev=eth0,mac=02:00:00:00:00:01" \
                -chardev stdio,id=stdio,signal=off \
                -serial chardev:stdio
            ''
          else
            vmConfig.microvm.declaredRunner;

          # Helper to substitute VM_RUNNER path in scripts
          substituteVmRunner = script:
            builtins.replaceStrings
              [ "VM_RUNNER_PLACEHOLDER" ]
              [ "${vmRunner}" ]
              script;

          # Scripts with proper dependencies
          agent-spawn = pkgs.writeShellApplication {
            name = "agent-spawn";
            runtimeInputs = with pkgs; [ coreutils git openssh jq openssl netcat ];
            text = substituteVmRunner (builtins.readFile ./bin/agent-spawn);
          };

          agent-attach = pkgs.writeShellApplication {
            name = "agent-attach";
            runtimeInputs = with pkgs; [ openssh jq coreutils netcat ];
            text = builtins.readFile ./bin/agent-attach;
          };

          agent-list = pkgs.writeShellApplication {
            name = "agent-list";
            runtimeInputs = with pkgs; [ coreutils jq ];
            text = builtins.readFile ./bin/agent-list;
          };

          agent-stop = pkgs.writeShellApplication {
            name = "agent-stop";
            runtimeInputs = with pkgs; [ coreutils jq procps ];
            text = builtins.readFile ./bin/agent-stop;
          };

          agent-resume = pkgs.writeShellApplication {
            name = "agent-resume";
            runtimeInputs = with pkgs; [ coreutils jq openssh netcat ];
            text = substituteVmRunner (builtins.readFile ./bin/agent-resume);
          };

          agent-test = pkgs.writeShellApplication {
            name = "agent-test";
            runtimeInputs = with pkgs; [ coreutils jq openssh netcat sshpass ];
            text = builtins.readFile ./bin/agent-test;
          };
        in {
          inherit agent-spawn agent-attach agent-list agent-stop agent-resume agent-test;
          default = agent-spawn;
        }
      );

      # Apps for easy running
      apps = forAllHostSystems (system: {
        agent-spawn = {
          type = "app";
          program = "${self.packages.${system}.agent-spawn}/bin/agent-spawn";
        };
        agent-attach = {
          type = "app";
          program = "${self.packages.${system}.agent-attach}/bin/agent-attach";
        };
        agent-list = {
          type = "app";
          program = "${self.packages.${system}.agent-list}/bin/agent-list";
        };
        agent-stop = {
          type = "app";
          program = "${self.packages.${system}.agent-stop}/bin/agent-stop";
        };
        agent-resume = {
          type = "app";
          program = "${self.packages.${system}.agent-resume}/bin/agent-resume";
        };
        agent-test = {
          type = "app";
          program = "${self.packages.${system}.agent-test}/bin/agent-test";
        };
        default = self.apps.${system}.agent-spawn;
      });

      # Development shell with all tools
      devShells = forAllHostSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.agent-spawn
              self.packages.${system}.agent-attach
              self.packages.${system}.agent-list
              self.packages.${system}.agent-stop
              self.packages.${system}.agent-resume
              self.packages.${system}.agent-test
            ];
          };
        }
      );
    };
}
