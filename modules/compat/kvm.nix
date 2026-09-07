{
  config,
  lib,
  pkgs,
  ...
}: let
  compatEnabled = config.features.compat.enable;
  cfg = config.features.compat.kvm;
in {
  options.features.compat.kvm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.compat.enable && false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
  };
}
