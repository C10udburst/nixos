{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  hostSettings = import ./settings.nix;
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ../../modules/nixos
  ];

  hostSettings = hostSettings;

  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  boot.kernelModules = [
    "hci_uart"
    "btintel"
    "btrtl"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
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
  ];
  hardware.sensor.iio.enable = true;

  # Accelerometer rotation mount matrix for Lenovo IdeaPad Miix 300
  services.udev.extraHwdb = ''
    sensor:modalias:acpi:SMO8500:*:dmi:bvnLENOVO:*:pvrMIIX300-*:*
    sensor:modalias:acpi:SMO8500:*:dmi:bvnLENOVO:*:pvr*300*:*
     ACCEL_MOUNT_MATRIX=0, -1, 0; -1, 0, 0; 0, 0, 1
  '';
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
    forcei686 = true;
    extraGrubInstallArgs = ["--target=i386-efi"];
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "cloudburst-tablet";

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${hostSettings.username}" = import ./home.nix;
    };
  };

  system.stateVersion = "26.05";
}
