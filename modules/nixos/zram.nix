{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.zram;
in {
  options.systemSettings.zram = {
    enable = lib.mkEnableOption "Enable zram swap device";
  };

  config = lib.mkIf cfg.enable {
    zramSwap = {
      enable = true;
      memoryPercent = lib.mkDefault (
        if config.hostSettings.slow or false
        then 100
        else 50
      );
      priority = lib.mkDefault 100;
    };

    swapDevices = [
      {
        device = "/var/swapfile";
        size = 8192;
        priority = 10;
      }
    ];

    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkDefault (
        if config.hostSettings.slow or false
        then 180
        else 150
      );
      "vm.watermark_boost_factor" = 0;
    };
  };
}
