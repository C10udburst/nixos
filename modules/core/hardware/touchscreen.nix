{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.touchscreen = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.touchscreen) {
    hardware.sensor.iio.enable = true;
    environment.systemPackages = [pkgs.iio-sensor-proxy];
  };
}
