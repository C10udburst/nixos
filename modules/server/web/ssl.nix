{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.ssl;
  baseDomain = config.features.server.web.core.baseDomain;
  tokenFile =
    if cfg.cloudflare.apiTokenFile != null
    then cfg.cloudflare.apiTokenFile
    else config.age.secrets.cloudflare-api-token.path;
in {
  options.features.server.web.ssl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
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

    security.acme = {
      acceptTerms = true;
      defaults = lib.mkIf (cfg.email != null) {
        email = cfg.email;
      };
      certs."${baseDomain}" = {
        domain = baseDomain;
        extraDomainNames = ["*.${baseDomain}"];
        dnsProvider = "cloudflare";
        environmentFile = tokenFile;
      };
    };
  };
}
