{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.services;
in {
  options.features.gui.services = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.enable && true;
    };
  };
}
