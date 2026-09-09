{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.apps.threed.enable;
  cfg = config.features.gui.apps.threed.orca;
in {
  options.features.gui.apps.threed.orca = lib.mkOption {
    type = lib.types.bool;
    default = threedEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.orca-slicer];
  };
}
