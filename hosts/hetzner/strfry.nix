{ config, pkgs, lib, ... }:

let
  cfgDir = "/etc/strfry";
  cfgPath = "${cfgDir}/strfry.conf";
  dbDir = "/var/lib/strfry/db";
in
{
  users.users.strfry = {
    isSystemUser = true;
    group = "strfry";
    home = "/var/lib/strfry";
  };
  users.groups.strfry = { };

  environment.etc."strfry/strfry.conf".text = ''
    ##
    ## strfry config (managed by NixOS)
    ##

    # Directory that contains the strfry LMDB database (restart required)
    db = "${dbDir}/"

    dbParams {
        maxreaders = 256
        mapsize = 10995116277760
        noReadAhead = false
    }

    events {
        maxEventSize = 65536
        rejectEventsNewerThanSeconds = 900
        rejectEventsOlderThanSeconds = 94608000
        rejectEphemeralEventsOlderThanSeconds = 60
        ephemeralEventsLifetimeSeconds = 300
        maxNumTags = 2000
        maxTagValSize = 1024
    }

    relay {
        # Only listen locally; Caddy terminates TLS and proxies websockets.
        bind = "127.0.0.1"
        port = 7777

        # We pass X-Real-IP from Caddy.
        realIpHeader = "x-real-ip"

        info {
            name = "relay.justinmoon.com"
            description = "Justin Moon's Nostr relay (strfry)."
            contact = "https://justinmoon.com"
        }

        maxWebsocketPayloadSize = 131072
        maxReqFilterSize = 200
        autoPingSeconds = 55
        enableTcpKeepalive = false
        queryTimesliceBudgetMicroseconds = 10000
        maxFilterLimit = 500
        maxSubsPerConnection = 20

        writePolicy {
            plugin = ""
        }

        compression {
            enabled = true
            slidingWindow = true
        }

        logging {
            invalidEvents = true
        }

        numThreads {
            ingester = 3
            reqWorker = 3
            reqMonitor = 3
            negentropy = 2
        }

        negentropy {
            enabled = true
            maxSyncEvents = 1000000
        }
    }
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/strfry 0750 strfry strfry -"
    "d ${dbDir} 0750 strfry strfry -"
  ];

  systemd.services.strfry = {
    description = "strfry Nostr relay";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "strfry";
      Group = "strfry";
      WorkingDirectory = cfgDir;
      ExecStart = "${pkgs.strfry}/bin/strfry relay";
      Restart = "on-failure";
      RestartSec = 2;

      # Strfry wants a very high fd limit; keep it explicit at the unit level.
      LimitNOFILE = 1000000;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      LockPersonality = true;

      ReadWritePaths = [ "/var/lib/strfry" ];
      ReadOnlyPaths = [ cfgPath ];
    };
  };

  environment.systemPackages = [
    pkgs.strfry
    (pkgs.writeShellScriptBin "strfry-status" ''
      echo "=== strfry status ==="
      systemctl status strfry --no-pager
      echo ""
      journalctl -u strfry -n 50 --no-pager
    '')
    (pkgs.writeShellScriptBin "strfry-logs" ''
      journalctl -u strfry -f
    '')
    (pkgs.writeShellScriptBin "strfry-restart" ''
      systemctl restart strfry
      systemctl is-active strfry && echo "strfry is running" || echo "strfry failed"
    '')
  ];
}

