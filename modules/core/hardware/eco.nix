{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
in {
  options.features.core.hardware.eco = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && cfg.mobile;
  };

  config = lib.mkIf cfg.eco {
    powerManagement = {
      enable = true;
      powertop.enable = true;
      cpuFreqGovernor = lib.mkDefault "powersave";
      scsiLinkPolicy = lib.mkDefault "med_power_with_dipm";
    };

    boot.kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
      "vm.dirty_writeback_centisecs" = 6000;
    };

    boot.extraModprobeConfig = ''
      options snd_hda_intel power_save=1 power_save_controller=Y
      options snd_ac97_codec power_save=1
    '';

    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    environment.systemPackages = [
      pkgs.powertop
    ];
  };
}
