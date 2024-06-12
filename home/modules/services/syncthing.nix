{ inputs, profile, homeDirectory }:
{ config, lib, pkgs, ... }:
let
  isRemote = profile == "remote";
  secretsPath = "${inputs.self}/secrets/syncthing-devices.nix";
  devicesConfig =
    if builtins.pathExists secretsPath then
      import secretsPath
    else
      {
        enable = false;
        mac = null;
        hetzner = null;
      };

  localKey = if isRemote then "hetzner" else "mac";
  remoteKey = if isRemote then "mac" else "hetzner";

  getDevice = key: lib.attrByPath [ key ] null devicesConfig;
  localDevice = getDevice localKey;
  remoteDevice = getDevice remoteKey;

  validId = device:
    device != null
    && lib.hasAttr "deviceId" device
    && device.deviceId != ""
    && !(lib.hasPrefix "REPLACE" device.deviceId);

  syncthingEnabled = (devicesConfig.enable or false) && validId localDevice && validId remoteDevice;

  listenAddresses =
    if localDevice != null && lib.hasAttr "listenAddresses" localDevice then
      localDevice.listenAddresses
    else
      [
        "tcp://0.0.0.0:22000"
        "quic://0.0.0.0:22000"
      ];

  guiAddress =
    if localDevice != null && lib.hasAttr "guiAddress" localDevice then
      localDevice.guiAddress
    else
      "127.0.0.1:8384";

  folderPath = "${homeDirectory}/sync";
  photosPath = "${folderPath}/photos";

  folderId = devicesConfig.folderId or "sync";
  folderLabel = devicesConfig.folderLabel or "Sync";

  stignoreText =
    if devicesConfig ? stignore then
      devicesConfig.stignore
    else
      ''
# Ignore OS metadata
(?d).DS_Store
(?d)Thumbs.db

# Build outputs
(?d)node_modules
(?d)target
(?d)dist
(?d).venv
(?d)__pycache__
(?d)tmp
(?d)result

# Version control detritus
(?d).git
(?d).svn
(?d).hg
      '';
in {
  config = lib.mkIf syncthingEnabled {
    services.syncthing = {
      enable = true;
      package = pkgs.syncthing;
      guiAddress = guiAddress;
      settings = {
        options = {
          listenAddresses = listenAddresses;
          globalAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
          localAnnounceEnabled = false;
        };
        devices = {
          "${localKey}" = {
            id = localDevice.deviceId;
            name =
              if localDevice ? name then
                localDevice.name
              else if isRemote then
                "hetzner"
              else
                "local";
            addresses = lib.attrByPath [ "addresses" ] [ "dynamic" ] localDevice;
            compression = lib.attrByPath [ "compression" ] "metadata" localDevice;
          };
          "${remoteKey}" = {
            id = remoteDevice.deviceId;
            name =
              if remoteDevice ? name then
                remoteDevice.name
              else if isRemote then
                "mac"
              else
                "hetzner";
            addresses = lib.attrByPath [ "addresses" ] [ ] remoteDevice;
            compression = lib.attrByPath [ "compression" ] "metadata" remoteDevice;
            introducer = lib.attrByPath [ "introducer" ] false remoteDevice;
          };
        };
        folders = {
          "${folderId}" =
            let
              folderOverrides = lib.attrByPath [ "folder" ] { } localDevice;
            in
              {
                id = folderId;
                label = folderLabel;
                path = folderPath;
                devices = [ localKey remoteKey ];
                ignorePerms = lib.attrByPath [ "ignorePerms" ] true localDevice;
                fsWatcherEnabled = lib.attrByPath [ "fsWatcherEnabled" ] true localDevice;
                rescanIntervalS = lib.attrByPath [ "rescanIntervalS" ] 3600 localDevice;
                type = lib.attrByPath [ "type" ] "sendreceive" localDevice;
              }
              // folderOverrides;
        };
      };
    };

    home.file."sync/.keep".text = "";
    home.file."sync/photos/.keep".text = "";
    home.file."sync/.stignore".text = stignoreText;

    home.activation.syncthingSyncDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      mkdir -p "${folderPath}" "${photosPath}"
      chmod 750 "${folderPath}" "${photosPath}"
    '';
  };
}
