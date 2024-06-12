{ config, lib, pkgs, inputs, ... }:

let
  domain = "moq.justinmoon.com";
  moqUser = "moq-relay";
  moqGroup = "moq-relay";
  stateDir = "/var/lib/moq-relay";
  certDir = "${stateDir}/certs";
  listenAddr = "[::]:443";
  caddyDataDir = config.services.caddy.dataDir or "/var/lib/caddy";
  caddyCertDir = "${caddyDataDir}/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${domain}";
  sourceCert = "${caddyCertDir}/${domain}.crt";
  sourceKey = "${caddyCertDir}/${domain}.key";
  localCert = "${certDir}/fullchain.pem";
  localKey = "${certDir}/privkey.pem";
  installBin = "${pkgs.coreutils}/bin/install";
  syncCertScript = pkgs.writeShellScript "moq-relay-sync-cert" ''
    set -euo pipefail

    if [ ! -f "${sourceCert}" ] || [ ! -f "${sourceKey}" ]; then
      echo "Caddy certificate for ${domain} is not available yet."
      echo "Make sure DNS for ${domain} points at this server so Caddy can issue it." >&2
      exit 1
    fi

    "${installBin}" -d -m 0750 -o ${moqUser} -g ${moqGroup} ${certDir}
    "${installBin}" -D -m 0640 -o ${moqUser} -g ${moqGroup} "${sourceCert}" "${localCert}"
    "${installBin}" -D -m 0600 -o ${moqUser} -g ${moqGroup} "${sourceKey}" "${localKey}"
  '';
  moqPackage = inputs.moq.packages.${pkgs.stdenv.hostPlatform.system}.moq-relay;
in
{
  services.moq-relay = {
    enable = true;
    package = moqPackage;
    user = moqUser;
    group = moqGroup;
    stateDir = stateDir;
    port = 443;
    logLevel = "info";
    auth.publicPath = "anon";
    tls.certs = [{
      chain = localCert;
      key = localKey;
    }];
  };

  networking.firewall.allowedUDPPorts = [ 443 ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 ${moqUser} ${moqGroup} -"
    "d ${certDir} 0750 ${moqUser} ${moqGroup} -"
  ];

  systemd.services.moq-relay = {
    after = [ "caddy.service" ];
    requires = [ "caddy.service" ];
    environment = lib.mkForce {
      MOQ_LOG_LEVEL = "info";
      MOQ_SERVER_LISTEN = listenAddr;
      MOQ_SERVER_TLS_CERT = localCert;
      MOQ_SERVER_TLS_KEY = localKey;
      MOQ_AUTH_PUBLIC = "anon";
      MOQ_CLIENT_TLS_DISABLE_VERIFY = "false";
      MOQ_WEB_HTTP_LISTEN = "127.0.0.1:4444";
    };
    serviceConfig = {
      ExecStartPre = lib.mkAfter [
        "+${syncCertScript}"
      ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "moq-relay-status" ''
      echo "=== moq-relay status ==="
      systemctl status moq-relay --no-pager
      echo ""
      echo "=== Recent logs ==="
      journalctl -u moq-relay -n 20 --no-pager
      echo ""
      echo "=== UDP sockets ==="
      ss -unlp | grep ':443 ' || echo "No listener on UDP/443"
    '')
    (writeShellScriptBin "moq-relay-logs" ''
      journalctl -u moq-relay -f
    '')
    (writeShellScriptBin "moq-relay-restart" ''
      systemctl restart moq-relay
      sleep 2
      systemctl is-active moq-relay && echo "✓ Service is running" || echo "✗ Service failed to start"
    '')
  ];
}
