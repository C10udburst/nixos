{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  boot.kernelModules = [
    "r8723bs"
    "hci_uart"
    "btrtl"
  ];

  security.rtkit.enable = true;

  boot.initrd.availableKernelModules = [
    "mmc_block"
    "sdhci"
    "sdhci_acpi"
    "sdhci_pci"
    "r8723bs"
  ];
  boot.initrd.kernelModules = [
    "mmc_block"
    "sdhci"
    "sdhci_acpi"
    "sdhci_pci"
  ];

  # Bootloader.
  boot.loader.timeout = 2;
  boot.kernelParams = [
    "fbcon=rotate:1"
    "intel_idle.max_cstate=1"
    "processor.max_cstate=1"
    "i915.enable_psr=0"
    "i915.enable_dc=0"
  ];

  # Disable systemd suspend/hibernate to prevent Bay Trail sleep lockups
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  hardware.sensor.iio.enable = true;

  # Accelerometer rotation mount matrix for Lenovo IdeaPad Miix 300
  services.udev.extraHwdb = ''
    sensor:modalias:acpi:SMO8500:*:dmi:bvnLENOVO:*:pvrMIIX300-*:*
    sensor:modalias:acpi:SMO8500:*:dmi:bvnLENOVO:*:pvr*300*:*
     ACCEL_MOUNT_MATRIX=0, -1, 0; -1, 0, 0; 0, 0, 1
  '';

  # Disable Wi-Fi power saving for stable connectivity (Realtek RTL8723BS)
  networking.networkmanager.wifi.powersave = false;

  # legacy graphics driver for Intel Bay Trail (i915)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  networking.hostName = "cloudburst-tablet";

  system.stateVersion = "26.05";
}
