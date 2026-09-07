{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.threed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
