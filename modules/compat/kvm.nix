{
  config,
  lib,
  ...
}: let
  cfg = config.features.compat.kvm;
  isGui = config.features.gui.enable;
in {
  options.features.compat.kvm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.compat.enable && false;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = lib.mkIf isGui true;
  };
}
