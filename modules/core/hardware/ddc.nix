{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware.ddc;
in {
  options.features.core.hardware.ddc = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.core.enable && config.features.core.hardware.enable && cfg) {
    environment.systemPackages = [pkgs.ddcutil];
    hardware.i2c.enable = true;
  };
}
