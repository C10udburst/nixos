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

  nixpkgs.overlays = [
    (final: prev: {
      driftwm = inputs.driftwm.packages.${prev.stdenv.hostPlatform.system}.default;
    })
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

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
