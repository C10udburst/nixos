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
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflare-api-token = {
      file = ../../../secrets/cloudflare-api-token.age;
    };

    services.caddy.package = pkgs.caddy.withPlugins {
      plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
      hash = "sha256-PWadA5qr/gR2qDcT8l8u1Xku7LM2HIfWTLOkzezCYy0=";
    };

    services.caddy.globalConfig = lib.mkAfter ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';
    systemd.services.caddy.serviceConfig.EnvironmentFile = [
      (
        if cfg.cloudflare.apiTokenFile != null
        then cfg.cloudflare.apiTokenFile
        else config.age.secrets.cloudflare-api-token.path
      )
    ];
  };
}
