{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.gitea;
  webCfg = config.features.server.web;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  storage = webCfg.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.gitea = lib.mkOption {
    type = lib.types.coercedTo lib.types.bool (b: { enable = b; }) (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = webCfg.enable && true;
          };
        };
      }
    );
    default = { };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "git";
        aliases = [ "gitea" ];
        port = 3000;
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/gitea 0750 git git - -"
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
