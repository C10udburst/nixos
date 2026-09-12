{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.immich;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.immich = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    ml = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "openvino";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "immich";
        aliases = [ "photos" ];
        port = 2283;
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        services.immich = {
          enable = true;
          port = 2283;
          host = "127.0.0.1";
          mediaLocation = "${storage}/immich";
          accelerationDevices = lib.optionals (cfg.ml == "openvino") [
            "/dev/dri/renderD128"
          ];
          machine-learning = {
            enable = cfg.ml != null;
            environment = lib.optionalAttrs (cfg.ml != null) {
              IMMICH_ACCELERATION_TYPE = cfg.ml;
            };
          };
        };
      }
    ]
  );
}
