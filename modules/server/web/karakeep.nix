{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.karakeep;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.karakeep = lib.mkOption {
    type = lib.types.coercedTo lib.types.bool (b: {enable = b;}) (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = webCfg.enable && true;
          };
        };
      }
    );
    default = {};
  };

  config = lib.mkIf cfg.enable (
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

        services.karakeep = {
          enable = true;
          extraEnvironment = {
            PORT = "3080";
            DATA_DIR = "${storage}/karakeep";
          };
        };
      }
    ]
  );
}
