{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.pi-dash;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  # The dashboard runs where the agents write their session logs, so this only
  # fronts that port; see shell.utils.llm.pi.web.dash for the service itself.
  dash = config.features.shell.utils.llm.pi.web.dash;
in {
  options.features.server.web.pi-dash = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    webHelper.mkWebApp {
      name = "pi-dash";
      aliases = [
        "pi-stats"
        "pi-analytics"
      ];
      upstream = "zeph:${toString dash.port}";
    }
  );
}
