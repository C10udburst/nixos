{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.threed.enable;
  cfg = config.features.gui.threed.openscad;
in {
  options.features.gui.threed.openscad = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if threedEnabled
        then true
        else false;
    };
  };

  config = lib.mkIf (threedEnabled && cfg.enable) {
    environment.systemPackages = [pkgs.openscad];
  };
}
