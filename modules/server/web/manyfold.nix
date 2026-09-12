{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.manyfold;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.manyfold = lib.mkOption {
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
        name = "3d";
        aliases = [
          "manyfold"
          "models"
          "stl"
        ];
        port = 3214;
        suspend = "podman-manyfold.service";
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/manyfold 0755 root root - -"
          "d ${storage}/manyfold/config 0755 root root - -"
          "d ${storage}/manyfold/libraries 0755 root root - -"
        ];

        virtualisation.oci-containers.containers.manyfold = {
          image = helpers.resolveImage "ghcr.io/manyfold3d/manyfold-solo:latest";
          ports = ["127.0.0.1:3214:3214"];
          volumes = [
            "${storage}/manyfold/config:/config"
            "${storage}/manyfold/libraries:/libraries"
          ];
          environment = {
            PUID = "1000";
            PGID = "1000";
          };
        };
      }
    ]
  );
}
