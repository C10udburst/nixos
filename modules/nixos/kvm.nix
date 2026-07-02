{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.kvm;
in {
  options.systemSettings.kvm = {
    enable = lib.mkEnableOption "Enable KVM virtualization (QEMU, Libvirtd, and Virt-Manager)";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
  };
}
