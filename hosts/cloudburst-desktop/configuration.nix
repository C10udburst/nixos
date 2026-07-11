# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
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
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.nix-flatpak.nixosModules.nix-flatpak
    ../../modules/nixos
  ];

  hostSettings = hostSettings;

  nixpkgs.overlays = [
    (final: prev: {
      driftwm = inputs.driftwm.packages.${prev.stdenv.hostPlatform.system}.default;
    })
  ];

  fileSystems."/mnt/dane" = {
    device = "/dev/disk/by-uuid/213C801055180E72";
    fsType = "lowntfs-3g";
    options = ["nofail" "rw" "windows_names" "ignore_case" "dmask=000" "fmask=000" "utf8" "noatime" "allow_other"];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;
  boot.loader.systemd-boot.extraInstallCommands = ''
    echo "auto-entries 0" >> ${config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf
  '';
  boot.initrd.kernelModules = ["amdgpu"];
  boot.supportedFilesystems = ["ntfs"];

  networking.hostName = "cloudburst-desktop"; # Define your hostname.
  networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
  networking.firewall.enable = false;

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${hostSettings.username}" = import ./home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "26.05";
}
