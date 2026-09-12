{
  config,
  lib,
  pkgs,
  helpers,
  ...
}:
let
  cfg = config.features.server.web.siyuan;
  storage = config.features.server.web.storage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.siyuan = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "siyuan";
        port = 6806;
        suspend = "podman-siyuan.service";
      })
      {
        systemd.tmpfiles.rules = [
          "d ${storage}/siyuan 0755 root root -"
        ];

        virtualisation.oci-containers.containers.siyuan = {
          image = helpers.resolveImage "b3log/siyuan:latest";
          ports = [
            "127.0.0.1:6806:6806"
          ];
          volumes = [
            "${storage}/siyuan:/siyuan/workspace"
          ];
          cmd = [
            "serve"
            "--workspace=/siyuan/workspace"
          ];
        };
      }
    ]
  );
}
