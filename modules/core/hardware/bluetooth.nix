{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.bluetooth = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.bluetooth) {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
