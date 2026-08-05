{
  config,
  lib,
  ...
}: {
  xdg.configFile."dolphinrc".source = ./dolphinrc.ini;
  xdg.dataFile."kxmlgui5/dolphin/dolphinui.rc".source = ./dolphinui.xml;

  xdg.dataFile."kio/servicemenus/vscode.desktop".source = ./vscode.desktop;

  xdg.dataFile."kio/servicemenus/gitr.desktop" = lib.mkIf config.homeSettings.programming.enable {
    source = ./gitr.desktop;
  };
}
