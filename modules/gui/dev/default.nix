{
  config,
  lib,
  ...
}: {
  options.features.gui.dev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.enable && false;
    };
  };
}
