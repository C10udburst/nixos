{
  config,
  lib,
  ...
}: {
  options.features.gui.apps.tools.social = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.apps.tools.enable && true;
    };
  };
}
