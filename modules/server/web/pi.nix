{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.pi;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  piWeb = config.features.shell.utils.llm.pi.web;
in {
  options.features.server.web.pi = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    webHelper.mkWebApp {
      name = "pi";
      aliases = [
        "pi-web"
        "pi-agent"
        "zeph"
      ];
      upstream = "zeph:${toString piWeb.port}";
    }
  );
}
