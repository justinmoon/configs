{ inputs }:

let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  hm = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      {
        home.username = "sprite";
        home.homeDirectory = "/home/sprite";
      }
      (import ../home {
        inputs = inputs;
        profile = "sprite";
        hostname = "container";
      })
    ];
    extraSpecialArgs = {
      inherit inputs;
    };
  };

  activationPackage = hm.activationPackage;

  closure = pkgs.closureInfo {
    rootPaths = [ activationPackage ];
  };
in
pkgs.runCommand "cockpit-sprite-env.tar.gz" { nativeBuildInputs = [ pkgs.gnutar pkgs.gzip pkgs.coreutils ]; } ''
  set -euo pipefail

  root="$TMPDIR/root"
  mkdir -p "$root/nix/store" "$root/opt"

  while read -r path; do
    cp -a "$path" "$root/nix/store/"
  done < ${closure}/store-paths

  ln -s ${activationPackage} "$root/opt/cockpit-hm"

  TZ=UTC
  tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -C "$root" -czf "$out" .
''
