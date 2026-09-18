{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.glances;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  port = 61208;
in {
  options.features.server.web.glances = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "glances";
        aliases = [
          "glance"
          "monitor"
        ];
        port = port;
        suspend = "glances.service";
      })
      {
        services.glances = {
          enable = true;
          port = port;
          extraArgs = [
            "-B"
            "127.0.0.1"
            "--webserver"
            "--disable-check-update"
          ];
        };
      }
    ]
  );
}
