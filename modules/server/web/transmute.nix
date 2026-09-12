{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.transmute;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.transmute = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (
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
        systemd.tmpfiles.rules = [
          "d ${storage}/transmute 0755 root root -"
        ];

        virtualisation.oci-containers.containers.transmute = {
          image = "ghcr.io/transmute-app/transmute:latest";
          ports = [
            "127.0.0.1:3313:3313"
          ];
          volumes = [
            "${storage}/transmute:/app/data"
          ];
        };
      }
    ]
  );
}
