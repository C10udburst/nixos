{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.ssl;
in {
  options.features.server.web.ssl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    cloudflare = {
      apiTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.cloudflare.apiTokenFile != null) {
    services.caddy.package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-PWadA5qr/gR2qDcT8l8u1Xku7LM2HIfWTLOkzezCYy0=";
    };

    services.caddy.globalConfig = lib.mkAfter ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';
    systemd.services.caddy.serviceConfig.EnvironmentFile = [
      cfg.cloudflare.apiTokenFile
    ];
  };
}
