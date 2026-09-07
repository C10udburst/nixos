{
  config,
  lib,
  ...
}: let
  cfg = config.features.core.hardware;
  podmanEnabled = config.features.compat.podman.enable or false;
in {
  options.features.core.hardware.nvidia = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf (config.features.core.enable && cfg.enable && cfg.nvidia) {
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      open = lib.mkDefault false;
      powerManagement.enable = lib.mkDefault false;
      powerManagement.finegrained = lib.mkDefault false;
      nvidiaSettings = true;
    };

    hardware.nvidia-container-toolkit.enable = lib.mkIf podmanEnabled true;
    virtualisation.containers.cdi.dynamic.nvidia.enable = lib.mkIf podmanEnabled true;
  };
}
