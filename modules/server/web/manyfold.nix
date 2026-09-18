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
    type = lib.types.bool;
    default = webCfg.enable && true;
  };

  config = lib.mkIf cfg (
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
        age.secrets.manyfold-env = {
          file = ../../../secrets/manyfold-env.age;
          owner = "manyfold";
          group = "manyfold";
          mode = "0400";
        };

        users.users.manyfold = {
          isSystemUser = true;
          group = "manyfold";
          home = "${storage}/manyfold";
          autoSubUidGidRange = true;
          linger = true;
        };
        users.groups.manyfold = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/manyfold 0750 manyfold manyfold - -"
          "d ${storage}/manyfold/config 0750 manyfold manyfold - -"
          "d ${storage}/manyfold/libraries 0750 manyfold manyfold - -"
        ];

        virtualisation.oci-containers.containers.manyfold = {
          image = helpers.resolveImage "ghcr.io/manyfold3d/manyfold-solo:latest";
          podman.user = "manyfold";
          ports = ["127.0.0.1:3214:3214"];
          volumes = [
            "${storage}/manyfold/config:/config"
            "${storage}/manyfold/libraries:/libraries"
          ];
          extraOptions = [
            "--userns=keep-id:uid=1000,gid=1000"
          ];
          environment = {
            PUID = "1000";
            PGID = "1000";
          };
          environmentFiles = [
            config.age.secrets.manyfold-env.path
          ];
        };
      }
    ]
  );
}
