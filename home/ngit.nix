{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "ngit";
  version = "2.2.3";

  src = if stdenv.isDarwin then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-universal-apple-darwin.tar.gz";
      sha256 = "585bfd211d0822248eb81a67abad69e8b45a6778f7e509ce3783aef8ae0ab33f";
    }
  else if stdenv.isLinux && stdenv.isx86_64 then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-x86_64-unknown-linux-gnu.2.17.tar.gz";
      sha256 = "f8f99c2d1d7cb7dcb99210cfd5b449da1a16606e8ea998973b9d8e2c0a5dbbd6";
    }
  else if stdenv.isLinux && stdenv.isAarch64 then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-aarch64-unknown-linux-gnu.2.17.tar.gz";
      sha256 = "bee637df2fb071224514f0f41f9f1cca802533203ab38b60071755605f86bfc9";
    }
  else
    throw "Unsupported platform";

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    install -m755 ngit $out/bin/ngit
    install -m755 git-remote-nostr $out/bin/git-remote-nostr
  '';

  meta = with lib; {
    description = "Nostr-based Git hosting and collaboration";
    homepage = "https://ngit.dev";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [];
  };
}
