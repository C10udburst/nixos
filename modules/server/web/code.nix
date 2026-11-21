{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.code;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  vscode = config.features.gui.apps.editors.vscode;
in {
  options.features.server.web.code = lib.mkOption {
    type = lib.types.bool;
    default = config.features.server.web.enable && true;
  };

  config = lib.mkIf cfg (
    webHelper.mkWebApp {
      name = "code";
      aliases = [
        "codium"
        "vscodium"
        "vscode"
      ];
      upstream = "zeph:${toString vscode.web.port}";
    }
  );
}
