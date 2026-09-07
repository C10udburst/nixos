{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.apps.threed.enable;
  cfg = config.features.gui.apps.threed.freecad;
in {
  options.features.gui.apps.threed.freecad = lib.mkOption {
    type = lib.types.bool;
    default =
      if threedEnabled
      then true
      else false;
  };

  config = lib.mkIf (threedEnabled && cfg) {
    environment.systemPackages = [pkgs.freecad];
  };
}
