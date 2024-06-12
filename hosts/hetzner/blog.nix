{ config, lib, pkgs, ... }:

let
  cfg = config.services.blog;
in
{
  options.services.blog = {
    enable = lib.mkEnableOption "Justin's blog";
    
    package = lib.mkOption {
      type = lib.types.package;
      description = "The blog package (built Astro site)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create symlink from /var/www/static/blog to the nix store
    systemd.tmpfiles.rules = [
      "L+ /var/www/static/blog - - - - ${cfg.package}"
    ];
  };
}
