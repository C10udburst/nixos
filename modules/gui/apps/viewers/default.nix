{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.apps.viewers;
in {
  options.features.gui.apps.viewers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if (config.features.gui.enable && config.features.gui.apps.enable)
        then true
        else false;
    };
  };
}
