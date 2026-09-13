{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.homarr;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
in {
  options.features.server.web.homarr = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && false;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "home";
        aliases = [
          "homarr"
          "homepage"
        ];
        port = 7575;
        suspend = "podman-homarr.service";
      })
      {
        users.users.homarr = {
          isSystemUser = true;
          group = "homarr";
          home = "${storage}/homarr";
          autoSubUidGidRange = true;
          linger = true;
          extraGroups = ["podman"];
        };
        users.groups.homarr = {};
        users.groups.podman = {};

        systemd.tmpfiles.rules = [
          "d ${storage}/homarr 0750 homarr homarr - -"
          "d ${storage}/homarr/appdata 0750 homarr homarr - -"
        ];

        virtualisation.oci-containers.containers.homarr = {
          image = helpers.resolveImage "ghcr.io/homarr-labs/homarr:latest";
          podman.user = "homarr";
          ports = [
            "127.0.0.1:7575:7575"
          ];
          volumes = [
            "${storage}/homarr/appdata:/appdata"
          ];
        };
      }
    ]
  );
}
