{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.zram = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.zram) {
    zramSwap = {
      enable = true;
      memoryPercent =
        if cfg.slow
        then 100
        else 50;
      priority = 100;
    };

    swapDevices = [
      {
        device = "/var/swapfile";
        size = 8192;
        priority = 10;
      }
    ];

    boot.kernel.sysctl = {
      "vm.swappiness" =
        if cfg.slow
        then 180
        else 150;
      "vm.watermark_boost_factor" = 0;
    };
  };
}
