{ config, lib, pkgs, ... }:

let
  cachePort = 5000;
in
{
  age.secrets.nix-cache-key = {
    file = ../../secrets/nix-cache-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.nix-serve = {
    enable = true;
    bindAddress = "0.0.0.0";
    port = cachePort;
    secretKeyFile = config.age.secrets.nix-cache-key.path;
  };
}
