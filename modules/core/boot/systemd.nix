{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.boot;
in {
  options.features.core.boot.systemd = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.boot.enable && !(cfg.grub or false) && !(cfg.grub32 or false);
  };

  config = lib.mkIf cfg.systemd {
    boot.loader.systemd-boot = {
      enable = true;
      extraInstallCommands = ''
        echo "auto-entries 0" >> ${config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf
      '';
    };
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  };
}
