{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.transmute;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.transmute = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "convert";
        aliases = [
          "convertx"
          "transmute"
        ];
        port = 3313;
        suspend = "podman-transmute.service";
        extraConfig = ''
          request_body {
            max_size 50000MB
          }
        '';
      })
      {
        users.users.transmute = {
          isSystemUser = true;
          group = "transmute";
          home = "${storage}/transmute";
          autoSubUidGidRange = true;
          linger = true;
          extraGroups = [
            "video"
            "render"
          ];
        };
        users.groups.transmute = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/transmute 2750 transmute web - -"
        ];

        virtualisation.oci-containers.containers.transmute = {
          image = helpers.resolveImage "ghcr.io/transmute-app/transmute:latest";
          podman.user = "transmute";
          ports = [
            "127.0.0.1:3313:3313"
          ];
          devices = [
            "/dev/dri:/dev/dri"
          ];
          volumes = [
            "${storage}/transmute:/app/data"
          ];
          environment = {
            ALLOW_UNAUTHENTICATED = "true";
          };
        };
      }
    ]
  );
}
