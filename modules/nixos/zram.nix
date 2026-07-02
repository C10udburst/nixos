{
  config,
  lib,
  pkgs,
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
      memoryPercent = 20;
    };
  };
}
