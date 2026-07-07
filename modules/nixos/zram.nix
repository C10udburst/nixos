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
      memoryPercent = 25;
      priority = 100;
    };

    swapDevices = [
      {
        device = "/var/swapfile";
        size = 8192; # Rozmiar w megabajtach (8 GB)
        priority = 10; # Niższy priorytet - używany dopiero po zapełnieniu ZRAM
      }
    ];

    boot.kernel.sysctl = {
      "vm.swappiness" = 150;
      "vm.watermark_boost_factor" = 0; # Opcjonalne: zapobiega nagłemu zrzucaniu pamięci na zram
    };
  };
}
