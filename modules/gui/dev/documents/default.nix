{
  config,
  lib,
  ...
}: {
  options.features.gui.dev.documents = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.dev.enable;
    };
  };
}
