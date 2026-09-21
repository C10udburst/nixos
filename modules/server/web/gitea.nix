{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.gitea;
  webCfg = config.features.server.web;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  storage = webCfg.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.gitea = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "git";
        aliases = ["gitea"];
        port = 3000;
      })
      {
        systemd.tmpfiles.rules = lib.mkOverride 990 (
          map (
            rule: builtins.replaceStrings ["0750 gitea gitea"] ["2750 gitea web"] rule
          )
          config.systemd.tmpfiles.rules
        );
      }
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/gitea 2750 gitea web - -"
        ];

        services.gitea = {
          enable = true;
          stateDir = "${storage}/gitea";
          settings = {
            server = {
              DOMAIN = "git.${baseDomain}";
              ROOT_URL = "https://git.${baseDomain}/";
              HTTP_PORT = 3000;
              DISABLE_SSH = true;
            };
            service = {
              DISABLE_REGISTRATION = false;
            };
          };
        };
      }
    ]
  );
}
