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
  options.features.server.web.homarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && false;
    };
  };

  config = lib.mkIf cfg.enable (
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
        systemd.tmpfiles.rules = [
          "d ${storage}/homarr 0755 root root - -"
          "d ${storage}/homarr/appdata 0755 root root - -"
        ];

        virtualisation.oci-containers.containers.homarr = {
          image = helpers.resolveImage "ghcr.io/homarr-labs/homarr:latest";
          ports = [
            "127.0.0.1:7575:7575"
          ];
          volumes = [
            "${storage}/homarr/appdata:/appdata"
            "/var/run/docker.sock:/var/run/docker.sock"
          ];
        };
      }
    ]
  );
}
