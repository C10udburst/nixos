{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.games;
in {
  options.features.gui.games = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
