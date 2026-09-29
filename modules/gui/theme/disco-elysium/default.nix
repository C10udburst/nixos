{
  config,
  lib,
  ...
}: {
  options.features.gui.theme.disco-elysium = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.theme.enable && false;
    };
  };
}
