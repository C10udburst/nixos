{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.boot;
  efiSysMountPoint =
    if config.fileSystems ? "/boot/efi"
    then "/boot/efi"
    else "/boot";
in {
  options.features.core.boot.grub = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.boot.enable && false;
  };

  config = lib.mkMerge [
    # 64-bit GRUB standalone (grub=true, grub32=false)
    (lib.mkIf (cfg.grub && !cfg.grub32) {
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
      boot.loader.efi.efiSysMountPoint = lib.mkDefault efiSysMountPoint;
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = lib.mkDefault true;
        device = "nodev";
        forcei686 = false;
        configurationLimit = lib.mkDefault 5;
      };
    })

    # Dual 64-bit and 32-bit GRUB (both grub=true and grub32=true)
    (lib.mkIf (cfg.grub && cfg.grub32) {
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
      boot.loader.efi.efiSysMountPoint = lib.mkDefault efiSysMountPoint;
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
        forcei686 = false;
        configurationLimit = lib.mkDefault 5;
        extraInstallCommands = ''
          ${pkgs.pkgsi686Linux.grub2_efi}/bin/grub-install --target=i386-efi --efi-directory=${efiSysMountPoint} --removable
        '';
      };
    })
  ];
}
