{
  config,
  lib,
  pkgs,
  pkgsUnstable,
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
        name = "photos";
        aliases = [
          "immich"
          "photo"
        ];
        port = 2283;
        suspend = [
          "immich-machine-learning.service"
          "immich-server.service"
          "redis-immich.service"
        ];
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/immich 2750 immich web - -"
          "d ${storage}/immich/cache 2750 immich web - -"
        ];

        systemd.tmpfiles.settings.immich."/opt/immich".e = {
          group = lib.mkForce "web";
          mode = lib.mkForce "2750";
        };

        users.users.immich.extraGroups = [
          "video"
          "render"
        ];

        services.immich = {
          enable = true;
          package = pkgsUnstable.immich;
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
              MACHINE_LEARNING_CACHE_FOLDER = lib.mkForce "${storage}/immich/cache";
              XDG_CACHE_HOME = lib.mkForce "${storage}/immich/cache";
              MPLCONFIGDIR = lib.mkForce "${storage}/immich/cache";
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
