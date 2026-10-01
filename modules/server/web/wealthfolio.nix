{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.wealthfolio;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  autheliaEnabled = config.features.server.web.authelia.enable or false;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.wealthfolio = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "wealth";
        aliases = ["wealthfolio"];
        port = 8088;
        suspend = "podman-wealthfolio.service";
        oidc = {
          id = "wealthfolio";
          name = "Wealthfolio";
          redirectUris = [
            "https://wealth.${baseDomain}/api/v1/auth/oidc/callback"
          ];
        };
      })
      {
        age.secrets.wealthfolio-env = {
          file = ../../../secrets/wealthfolio-env.age;
          owner = "wealthfolio";
          group = "wealthfolio";
          mode = "0400";
        };

        users.users.wealthfolio = {
          isSystemUser = true;
          group = "wealthfolio";
          home = "${storage}/wealthfolio";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.wealthfolio = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/wealthfolio 0751 wealthfolio web - -"
          "z ${storage}/wealthfolio 0751 wealthfolio web - -"
        ];

        virtualisation.oci-containers.containers.wealthfolio = {
          image = helpers.resolveImage "ghcr.io/wealthfolio/wealthfolio:latest";
          podman.user = "wealthfolio";
          ports = [
            "127.0.0.1:8088:8088"
          ];
          volumes = [
            "${storage}/wealthfolio:/data"
          ];
          extraOptions = [
            "--userns=keep-id:uid=1000,gid=1000"
          ];
          environment =
            {
              WF_LISTEN_ADDR = "0.0.0.0:8088";
              WF_DB_PATH = "/data/wealthfolio.db";
              WF_CORS_ALLOW_ORIGINS = "https://wealth.${baseDomain}";
            }
            // lib.optionalAttrs autheliaEnabled {
              WF_OIDC_ENABLED = "true";
              WF_OIDC_ISSUER_URL = "https://auth.${baseDomain}";
              WF_OIDC_CLIENT_ID = "wealthfolio";
              WF_OIDC_REDIRECT_URL = "https://wealth.${baseDomain}/api/v1/auth/oidc/callback";
              WF_OIDC_SCOPES = "openid email profile";
              WF_OIDC_ALLOW_ANY = "true";
              WF_OIDC_POST_LOGOUT_REDIRECT_URL = "https://wealth.${baseDomain}";
            };
          environmentFiles = [
            config.age.secrets.wealthfolio-env.path
          ];
        };
      }
    ]
  );
}
