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
      # Enable the open-source kernel module (required for Turing/Ampere+ for Wayland)
      open = lib.mkDefault false;
      # Power management — helps with suspend/resume
      powerManagement.enable = lib.mkDefault false;
      powerManagement.finegrained = lib.mkDefault false;
      # NVIDIASettings GUI tool
      nvidiaSettings = true;
    };

    # Enable CUDA support system-wide
    hardware.nvidia-container-toolkit.enable = lib.mkIf podmanEnabled true;

    # Allow unfree packages needed for NVIDIA drivers and CUDA
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;

    # CUDA toolkit and related tools in system packages
    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      cudaPackages.cuda_nvcc
      nvtopPackages.nvidia
    ];

    # Podman CDI (Container Device Interface) for GPU passthrough
    # Enabled automatically when both nvidia and podman are on
    virtualisation.containers.cdi.dynamic.nvidia.enable = lib.mkIf podmanEnabled true;
  };
}
