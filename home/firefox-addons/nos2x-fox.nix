{ buildFirefoxXpiAddon, fetchurl, lib }:

buildFirefoxXpiAddon rec {
  pname = "nos2x-fox";
  version = "1.17.0";
  addonId = "{4c4a6d3a-eb53-4868-9181-e0e0127d3c9c}";

  url = "https://addons.mozilla.org/firefox/downloads/file/4406254/nos2x_fox-${version}.xpi";
  sha256 = "sha256-bssfZK442FDFnWcCrbjlYRTPITwX6UEe9Xi4+lRvmdM=";

  meta = with lib; {
    description = "Nostr signer extension for Firefox";
    homepage = "https://github.com/diegogurpegui/nos2x-fox";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
