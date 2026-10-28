# Hardware configuration for Microsoft Surface Go.
#
# Matches the layout produced by the root ./disko.nix: partition NAMES are
# used (/dev/disk/by-partlabel), so the exact same file works whether the
# system is installed on a USB stick or on the internal NVMe.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "mmc_block"
    "sdhci"
    "sdhci_acpi"
    "sdhci_pci"
    "nvme"
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-partlabel/surface-esp";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
      "noatime"
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/surface-root";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "noatime"
      "compress=zstd"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-partlabel/surface-root";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "noatime"
      "compress=zstd"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-partlabel/surface-root";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "noatime"
      "compress=zstd"
      "ssd"
      "discard=async"
    ];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
