{
  config,
  lib,
  ...
}: {
  options.features.gui.games = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.enable && false;
    };
  };
}
