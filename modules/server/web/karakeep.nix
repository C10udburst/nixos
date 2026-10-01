{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  cfg = config.features.server.web.karakeep;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  autheliaEnabled = config.features.server.web.authelia.enable or false;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.karakeep = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (lib.mkIf autheliaEnabled {
        services.karakeep.extraEnvironment = {
          OAUTH_WELLKNOWN_URL = "https://auth.${baseDomain}/.well-known/openid-configuration";
          OAUTH_CLIENT_ID = "karakeep";
          OAUTH_PROVIDER_NAME = "Authelia";
          OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKING = "true";
        };
      })
      (webHelper.mkWebApp {
        name = "bookmarks";
        aliases = [
          "book"
          "karakeep"
          "bookmark"
        ];
        port = 3080;
        suspend = [
          "karakeep-web.service"
          "karakeep-workers.service"
          "karakeep-browser.service"
          "meilisearch.service"
        ];
        oidc = {
          id = "karakeep";
          name = "Karakeep";
          redirectUris = [
            "https://bookmarks.${baseDomain}/api/auth/callback/custom"
          ];
        };
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/karakeep 2750 karakeep web - -"
          "L+ /var/lib/karakeep - - - - ${storage}/karakeep"
        ];

        systemd.services.karakeep-init = {
          environment.STATE_DIRECTORY = "/var/lib/karakeep";
          serviceConfig.StateDirectory = lib.mkForce [];
        };
        systemd.services.karakeep-web.serviceConfig = {
          StateDirectory = lib.mkForce [];
          SuccessExitStatus = [143];
        };
        systemd.services.karakeep-workers.serviceConfig.StateDirectory = lib.mkForce [];

        services.meilisearch = {
          settings.no_analytics = true;
        };

        age.secrets.karakeep-env = {
          file = ../../../secrets/karakeep-env.age;
        };

        services.karakeep = {
          enable = true;
          package = pkgsUnstable.karakeep;
          environmentFile = config.age.secrets.karakeep-env.path;
          browser.enable = true;
          meilisearch.enable = true;
          extraEnvironment = {
            PORT = "3080";
            NEXTAUTH_URL = "https://bookmarks.${baseDomain}";
          };
        };
      }
    ]
  );
}
