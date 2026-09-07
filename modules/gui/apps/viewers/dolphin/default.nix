{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.viewers.dolphin;
  viewersEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.viewers.enable;
  isVscode = config.features.gui.apps.editors.vscode or false;
  isProgramming = config.features.gui.dev.programming.enable or false;
in {
  options.features.gui.apps.viewers.dolphin = lib.mkOption {
    type = lib.types.bool;
    default = viewersEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.kdePackages.dolphin];

    home-manager.users.cloudburst = {
      xdg.configFile."dolphinrc".source = ./_dolphinrc.ini;
      xdg.dataFile."kxmlgui5/dolphin/dolphinui.rc".source = ./_dolphinui.xml;

      xdg.dataFile."kio/servicemenus/vscode.desktop" = lib.mkIf isVscode {
        source = ./_vscode.desktop;
      };

      xdg.dataFile."kio/servicemenus/gitr.desktop" = lib.mkIf isProgramming {
        source = ./_gitr.desktop;
      };

      xdg.mimeApps.defaultApplications = {
        "inode/directory" = ["org.kde.dolphin.desktop"];
        "application/zip" = ["org.kde.dolphin.desktop"];
      };
    };
  };
}
