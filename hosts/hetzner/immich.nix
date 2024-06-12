{ lib, ... }:
let
  mediaRoot = "/home/justin/sync/photos";
  secretsPath = "/var/lib/immich/immich.env";
in {
  services.immich = {
    enable = true;
    mediaLocation = mediaRoot;
    host = "0.0.0.0";
    port = 2283;
    openFirewall = false;
    user = "justin";
    group = "users";
    secretsFile = secretsPath;
    settings = {
      server.externalDomain = "https://photos.justinmoon.com";
    };
    database = {
      name = "justin";
      user = "justin";
    };
    machine-learning.environment = {
      MPLCONFIGDIR = "/var/cache/immich/matplotlib";
    };
  };

  systemd.tmpfiles.rules =
    [
      "d /home/justin/sync 0750 justin users - -"
      "d ${mediaRoot} 0750 justin users - -"
      "d /var/lib/immich 0750 justin users - -"
    ];

  system.activationScripts.immichSyncDirs = {
    deps = [ "users" ];
    text = ''
      install -d -m 0750 -o justin -g users /home/justin/sync
      install -d -m 0750 -o justin -g users ${mediaRoot}
    '';
  };

  systemd.services.immich-server.serviceConfig = {
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce "strict";
    ReadWritePaths = [
      "/home/justin/sync"
      "/var/lib/immich"
    ];
  };
}
