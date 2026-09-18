{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  cfg = config.features.server.web.karakeep;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.karakeep = lib.mkOption {
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "bookmarks";
        aliases = [
          "book"
          "karakeep"
          "bookmark"
        ];
        port = 3080;
        suspend = "karakeep-web.service";
      })
      {

        systemd.tmpfiles.rules = [
          "d ${storage}/karakeep 0750 karakeep karakeep - -"
        ];

        services.meilisearch = {
          settings.no_analytics = true;
        };

        services.karakeep = {
          enable = true;
          package = pkgsUnstable.karakeep;
          browser.enable = true;
          meilisearch.enable = true;
          extraEnvironment = {
            PORT = "3080";
          };
        };

        systemd.services.karakeep-web.environment.DATA_DIR = lib.mkForce "${storage}/karakeep";
        systemd.services.karakeep-workers.environment.DATA_DIR = lib.mkForce "${storage}/karakeep";
      }
    ]
  );
}
