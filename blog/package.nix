{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "justinmoon-blog";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    bun
    nodejs_22
    vips
    pkg-config
    python3
  ];

  buildPhase = ''
    export HOME=$TMPDIR
    bun install --frozen-lockfile
    bunx --bun astro build
  '';

  installPhase = ''
    cp -r dist $out
  '';

  meta = with pkgs.lib; {
    description = "Justin Moon's personal blog";
    license = licenses.mit;
  };
}
