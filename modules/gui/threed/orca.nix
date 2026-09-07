{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.threed.enable;
  cfg = config.features.gui.threed.orca;
in {
  options.features.gui.threed.orca = lib.mkOption {
    type = lib.types.bool;
    default =
      if threedEnabled
      then true
      else false;
  };

  config = lib.mkIf (threedEnabled && cfg) {
    environment.systemPackages = [pkgs.orca-slicer];
  };
}
