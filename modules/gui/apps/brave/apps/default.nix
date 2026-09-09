{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.brave.apps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.brave.enable;
    };
  };
}
