{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.eightmb;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.eightmb = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "8mb";
        aliases = [
          "eightmb"
          "compress"
        ];
        port = 8002;
        suspend = "podman-eightmb.service";
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        users.users.eightmb = {
          isSystemUser = true;
          group = "eightmb";
          home = "${storage}/eightmb";
          autoSubUidGidRange = true;
          linger = true;
          extraGroups = [
            "video"
            "render"
          ];
        };
        users.groups.eightmb = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/eightmb 0750 eightmb eightmb - -"
          "d ${storage}/eightmb/outputs 0750 eightmb eightmb - -"
          "d ${storage}/eightmb/uploads 0750 eightmb eightmb - -"
        ];

        virtualisation.oci-containers.containers.eightmb = {
          image = helpers.resolveImage "docker.io/jms1717/8mblocal:latest";
          podman.user = "eightmb";
          ports = [
            "127.0.0.1:8002:8001"
          ];
          devices = [
            "/dev/dri:/dev/dri"
          ];
          volumes = [
            "${storage}/eightmb/outputs:/app/outputs"
            "${storage}/eightmb/uploads:/app/uploads"
          ];
        };
      }
    ]
  );
}
