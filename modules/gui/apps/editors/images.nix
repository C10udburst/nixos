{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.images;
  editorsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.editors.enable;
in {
  options.features.gui.apps.editors.images = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (editorsEnabled && cfg) {
    environment.systemPackages = with pkgs; [
      gimp
      inkscape
    ];
  };
}
