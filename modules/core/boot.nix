{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.boot;
in {
  options.features.core.boot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.core.enable
        then true
        else false;
    };
    systemd = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    grub32 = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    timeout = lib.mkOption {
      type = lib.types.int;
      default = 2;
    };
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable) {
    boot.loader.timeout = cfg.timeout;

    boot.loader.systemd-boot = lib.mkIf cfg.systemd {
      enable = true;
      extraInstallCommands = ''
        echo "auto-entries 0" >> ${config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf
      '';
    };

    boot.loader.efi.canTouchEfiVariables =
      if cfg.grub32
      then false
      else true;

    boot.loader.grub = lib.mkIf cfg.grub32 {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      forcei686 = true;
      extraGrubInstallArgs = ["--target=i386-efi"];
      configurationLimit = 1;
    };
  };
}
