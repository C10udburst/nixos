{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.server.web.homepage;
  webHelper = import ./_webService.nix { inherit config lib pkgs; };
in
{
  options.features.server.web.homepage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "home";
        aliases = [
          "homepage"
          "homarr"
        ];
        port = 8082;
      })
      {
        services.homepage-dashboard = {
          enable = true;
          listenPort = 8082;
        };
      }
    ]
  );
}
