{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.tools = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.apps.enable
        then true
        else false;
    };
  };
}
