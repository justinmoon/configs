{
  lib,
  pkgs,
}: let
  ai-shell = pkgs.buildNpmPackage rec {
    pname = "ai-shell";
    version = "1.0.12";

    src = pkgs.fetchFromGitHub {
      owner = "BuilderIO";
      repo = "ai-shell";
      rev = "v${version}";
      sha256 = "0dnpx5r8hbldp1mn2m7wv8rckar0dis06g8pz03m2b0ljzrg1p86";
    };

    npmDepsHash = "sha256-wlJhq0GoHdH6Sr/L6R0PKJ+U/7g+Qky0g1kzU8bjehE=";

    # Custom build phase using Bun instead of npm
    buildPhase = ''
      ${pkgs.bun}/bin/bun build ./src/cli.ts --outdir ./dist --target bun
    '';

    # If needed for the installation
    makeCacheWritable = true;

    nativeBuildInputs = [pkgs.makeWrapper pkgs.bun];

    # Add this to properly expose the built package
    installPhase = ''
      mkdir -p $out/bin
      cp -r dist/* $out/

      # Create a mock sw_vers script
      # (MASSIVE HACK!!!)
      cat > $out/bin/sw_vers << 'EOF'
      #!/bin/sh
      echo "ProductName:    macOS"
      echo "ProductVersion: 14.0"
      echo "BuildVersion:   23A344"
      EOF
      chmod +x $out/bin/sw_vers

      # Create the bin symlink with Bun instead of Node
      makeWrapper ${pkgs.bun}/bin/bun $out/bin/ai \
        --add-flags $out/cli.js \
        --set PATH $out/bin:${lib.makeBinPath [
        pkgs.darwin.apple_sdk.frameworks.CoreServices
        # Add apple-specific tools that provide sw_vers
        pkgs.darwin.cctools
        # If you're on Darwin, add Command Line Tools
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
      ]}:$PATH
    '';

    meta = with lib; {
      description = "AI Shell - a CLI tool powered by AI";
      homepage = "https://github.com/BuilderIO/ai-shell";
      license = licenses.mit; # Adjust if different
      maintainers = with maintainers; ["builderio"];
    };
  };
in
  ai-shell
