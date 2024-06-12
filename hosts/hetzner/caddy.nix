{ config, pkgs, lib, ... }:

{
  # Caddy reverse proxy configuration
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/namecheap@v0.1.1-0.20250828013603-bca76890760d" ];
      hash = "sha256-1BKC0UpraEyvPlMZSG07VRdN4FPvS9vZ1f7vb9JioZU=";
    };

    virtualHosts = {
      # Wildcard site for everything under *.justinmoon.com (plus apex)
      "justinmoon.com, *.justinmoon.com" = {
        extraConfig = ''
          # Use DNS challenge against Namecheap so wildcard certs cover any subdomain
          tls {
            dns namecheap {
              user {$NAMECHEAP_API_USER}
              api_key {$NAMECHEAP_API_KEY}
              client_ip {$NAMECHEAP_CLIENT_IP}
            }
          }

          @apex_static {
            host justinmoon.com
            path /s/*
          }
          handle @apex_static {
            handle_path /s/* {
              root * /var/www/static/s
              file_server {
                browse
              }
              
              # Set proper MIME types for JavaScript modules
              @js path *.js *.mjs
              header @js Content-Type "application/javascript"
              
              # Set MIME type for WebAssembly
              @wasm path *.wasm
              header @wasm Content-Type "application/wasm"
              
              # Set MIME type for CSS
              @css path *.css
              header @css Content-Type "text/css"
              
              # Set MIME type for JSON
              @json path *.json
              header @json Content-Type "application/json"
            }
          }

          @apex host justinmoon.com
          handle @apex {
            # Blog - served from /var/www/static/blog
            root * /var/www/static/blog
            try_files {path} {path}/ /index.html
            file_server
          }

          @vibe host vibe.justinmoon.com
          handle @vibe {
            root * /var/www/static/vibe
            try_files {path} {path}/ /index.txt
            file_server
          }

          @www host www.justinmoon.com
          handle @www {
            redir https://justinmoon.com{uri} permanent
          }

          # MoQ service
          @moq host moq.justinmoon.com
          handle @moq {
            reverse_proxy 127.0.0.1:4444 {
              header_up Host {http.request.header.Host}
              header_up X-Real-IP {http.request.header.X-Real-IP}
              header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
              header_up X-Forwarded-Proto {http.request.header.X-Forwarded-Proto}
            }
          }

          @www_moq host www.moq.justinmoon.com
          handle @www_moq {
            redir https://moq.justinmoon.com{uri} permanent
          }

          # Static subdomain for future use
          @setup host setup.justinmoon.com
          handle @setup {
            redir https://gist.githubusercontent.com/justinmoon/23634343a270ea418ddf3e94cd227e68/raw/setup.sh permanent
          }

          @static host static.justinmoon.com
          handle @static {
            root * /var/www/static
            file_server {
              browse
            }
          }

          # Fail closed for anything we are not explicitly handling yet.
          handle {
            respond "Justin's Server" 404
          }
        '';
      };
      
    };
    
    # Global Caddy configuration for better certificate handling
    globalConfig = ''
      # Increase rate limits for Let's Encrypt and disable HTTP/3 to keep UDP :443 free for MoQ
      servers {
        protocols h1 h2
        timeouts {
          read_body 30s
          read_header 30s
          write 30s
          idle 120s
        }
      }
    '';
  };
  
  # Create static directory with proper permissions and hold optional secret dir
  systemd.tmpfiles.rules = [
    "d /var/www/static 0755 justin users -"
    "d /etc/secrets 0750 root caddy -"
  ];

  # Optional environment file pulled in at deploy time (e.g. via 1Password)
  systemd.services.caddy.serviceConfig.EnvironmentFile = [ "-/etc/secrets/namecheap-dns.env" ];
  
  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
