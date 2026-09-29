{
  config,
  lib,
  ...
}: {
  options.features.gui.theme.nature = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.theme.enable && true;
    };
  };
}
