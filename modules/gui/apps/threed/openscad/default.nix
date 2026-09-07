{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.apps.threed.enable;
  cfg = config.features.gui.apps.threed.openscad;
in {
  options.features.gui.apps.threed.openscad = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = threedEnabled && true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.openscad];
  };
}
