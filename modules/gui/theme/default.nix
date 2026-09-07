{
  config,
  lib,
  ...
}: {
  options.features.gui.theme = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
  };
}
