{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.nvidia;
  podmanEnabled = config.systemSettings.podman.enable;
in {
  options.systemSettings.nvidia = {
    enable = lib.mkEnableOption "Enable NVIDIA GPU drivers and CUDA support";
  };

  config = lib.mkIf cfg.enable {
    # Load the NVIDIA kernel module and enable modesetting
    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {
      # Use the production/stable driver series
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      # Kernel modesetting is required for Wayland
      modesetting.enable = true;
      # Open-source kernel module (for Turing/Ampere+); set true if supported
      open = lib.mkDefault false;
      # Power management
      powerManagement.enable = lib.mkDefault false;
      powerManagement.finegrained = lib.mkDefault false;
      # NVIDIASettings GUI
      nvidiaSettings = true;
    };

    # Allow unfree packages for the proprietary NVIDIA driver
    nixpkgs.config.allowUnfree = true;

    # Lightweight CUDA tools: compiler + runtime headers only.
    # Deliberately excludes cudatoolkit (pulls in libnvshmem/ucx/openmpi
    # which require DOCA/InfiniBand headers and fail to build).
    environment.systemPackages = with pkgs; [
      cudaPackages.cuda_nvcc # CUDA compiler
      cudaPackages.cuda_cudart # CUDA runtime headers/libs
      nvtopPackages.nvidia # GPU process monitor
    ];

    # nvidia-container-toolkit enables CDI GPU passthrough for Podman/Docker.
    # Activated automatically when both nvidia and podman flags are on.
    hardware.nvidia-container-toolkit.enable = lib.mkIf podmanEnabled true;
    virtualisation.containers.cdi.dynamic.nvidia.enable = lib.mkIf podmanEnabled true;
  };
}
