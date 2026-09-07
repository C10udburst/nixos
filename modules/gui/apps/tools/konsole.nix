{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.konsole;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable;
in {
  options.features.gui.apps.tools.konsole = lib.mkOption {
    type = lib.types.bool;
    default = (config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable) && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.kdePackages.konsole];

    home-manager.users.cloudburst = {
      xdg.terminal-exec = {
        enable = true;
        settings = {
          default = ["org.kde.konsole.desktop"];
        };
      };

      home.sessionVariables = {
        TERMINAL = "konsole";
      };
    };
  };
}
