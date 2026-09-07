{
  config,
  lib,
  ...
}: {
  options.features.gui.threed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
