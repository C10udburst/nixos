{
  config,
  pkgs,
  lib,
  inputs,
  pkgsUnstable,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.msi-gl65-10SDR-492
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  # msi-ec out-of-tree kernel module for MSI Embedded Controller support
  boot.extraModulePackages = [
    (pkgsUnstable.linuxKernel.packagesFor config.boot.kernelPackages.kernel).msi-ec
  ];
  boot.kernelModules = [
    "msi-ec"
  ];

  networking.hostName = "cloudburst-laptop";

  system.stateVersion = "26.05";
}
