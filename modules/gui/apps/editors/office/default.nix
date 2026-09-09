{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.editors.office = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.editors.enable;
    };
  };
}
