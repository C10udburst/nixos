{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;
  podmanEnabled = config.features.compat.podman.enable or false;
  isGui = config.features.gui.enable;
in {
  options.features.core.hardware.nvidia = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && false;
  };

  config = lib.mkIf cfg.nvidia {
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      open = lib.mkDefault false;
      powerManagement.enable = lib.mkDefault false;
      powerManagement.finegrained = lib.mkDefault false;
      nvidiaSettings = isGui;
    };

    environment.systemPackages = [
      pkgs.nvtopPackages.nvidia
    ];

    hardware.nvidia-container-toolkit.enable = lib.mkIf podmanEnabled true;
  };
}
