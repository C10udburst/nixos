{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.boot;
in {
  options.features.core.boot.grub32 = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.boot.enable && false;
  };

  config = lib.mkIf cfg.grub32 {
    boot.loader.efi.canTouchEfiVariables = false;
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      forcei686 = true;
      extraGrubInstallArgs = ["--target=i386-efi"];
      configurationLimit = 2;
    };
  };
}
