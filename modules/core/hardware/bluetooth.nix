{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.bluetooth = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && true;
  };

  config = lib.mkIf cfg.bluetooth {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
