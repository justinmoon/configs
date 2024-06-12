{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "ngit";
  version = "2.0.0";

  src = if stdenv.isDarwin then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-universal-apple-darwin.tar.gz";
      sha256 = "791d0696e06c304d040aa3534cb7427af5febaa459870ce91812e16ecb738bc7";
    }
  else if stdenv.isLinux && stdenv.isx86_64 then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-x86_64-unknown-linux-gnu.2.17.tar.gz";
      sha256 = "e13a711e79f6f2522d557e0cae51c909f02921a5531893ec68a264efe7595a87";
    }
  else if stdenv.isLinux && stdenv.isAarch64 then
    fetchurl {
      url = "https://github.com/DanConwayDev/ngit-cli/releases/download/v${version}/ngit-v${version}-aarch64-unknown-linux-gnu.2.17.tar.gz";
      sha256 = "b281b15bbd816f8e0cbf6332804d93fa13dbdd143836a57210160d8e0e72b1a3";
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
