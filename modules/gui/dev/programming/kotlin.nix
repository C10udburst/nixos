{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled =
    config.features.gui.enable
    && config.features.gui.dev.enable
    && config.features.gui.dev.programming.enable;
  cfg = config.features.gui.dev.programming.kotlin;
in {
  options.features.gui.dev.programming.kotlin = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (devEnabled && cfg) {
    environment.systemPackages = [pkgs.kotlin];
  };
}
