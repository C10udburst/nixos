{
  config,
  lib,
  ...
}: {
  xdg.configFile."dolphinrc".source = ./dolphinrc.ini;
  xdg.dataFile."kxmlgui5/dolphin/dolphinui.rc".source = ./dolphinui.xml;
}
