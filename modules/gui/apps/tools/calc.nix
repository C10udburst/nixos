{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.calc;
  toolsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.calc = lib.mkOption {
    type = lib.types.bool;
    default =
      if toolsEnabled
      then true
      else false;
  };

  config = lib.mkIf (toolsEnabled && cfg) {
    environment.systemPackages = [pkgs.qalculate-qt];
  };
}
