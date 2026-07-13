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
    inputs.nix-flatpak.nixosModules.nix-flatpak
    ../../modules/nixos
  ];

  hostSettings = hostSettings;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  # MSI Embedded Controller (EC) support
  boot.extraModulePackages = [config.boot.kernelPackages.msi-ec];
  boot.kernelModules = ["msi-ec"];
  boot.kernelParams = ["ec_sys.write_support=1"];
  boot.extraModprobeConfig = ''
    options msi-ec force_id="16U7EMS1" debug=1
  '';

  networking.hostName = "cloudburst-laptop";
  networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
  networking.firewall.enable = false;

  home-manager = {
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${hostSettings.username}" = import ./home.nix;
    };
  };

  system.stateVersion = "26.05";
}
