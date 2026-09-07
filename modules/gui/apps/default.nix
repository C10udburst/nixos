{
  config,
  lib,
  ...
}: {
  options.features.gui.apps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
  };
}
