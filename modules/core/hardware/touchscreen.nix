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
    default = (config.features.core.enable && config.features.core.hardware.enable) && false;
  };

  config = lib.mkIf cfg.touchscreen {
    hardware.sensor.iio.enable = true;
    environment.systemPackages = [pkgs.iio-sensor-proxy];
  };
}
