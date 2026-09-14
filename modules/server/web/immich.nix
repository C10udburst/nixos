{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.immich;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
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
        aliases = ["photos"];
        port = 2283;
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/immich/cache 0750 immich immich - -"
        ];

        users.users.immich.extraGroups = [
          "video"
          "render"
        ];

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
              MACHINE_LEARNING_CACHE_FOLDER = "${storage}/immich/cache";
              XDG_CACHE_HOME = "${storage}/immich/cache";
              MPLCONFIGDIR = "${storage}/immich/cache";
            };
          };
        };

        systemd.services.immich-machine-learning = lib.mkIf (cfg.ml != null) {
          serviceConfig = {
            CPUQuota = "200%";
          };
        };
      }
    ]
  );
}
