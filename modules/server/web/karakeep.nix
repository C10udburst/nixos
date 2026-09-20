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
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
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
        suspend = [
          "karakeep-web.service"
          "karakeep-workers.service"
          "karakeep-browser.service"
          "meilisearch.service"
        ];
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

        services.karakeep = {
          enable = true;
          package = pkgsUnstable.karakeep;
          browser.enable = true;
          meilisearch.enable = true;
          extraEnvironment = {
            PORT = "3080";
          };
        };
      }
    ]
  );
}
