{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.microsoft-surface-go

    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  # ── Kernel Selection ────────────────────────────────────────────────────────
  # By default, nixos-hardware's microsoft-surface-go module pulls in the custom
  # linux-surface kernel (built from source with Surface hardware patches).
  # Forcing standard nixpkgs Linux for now for fast builds and first boot tests.
  # To test the patched linux-surface kernel instead, comment this line out:
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "surface";

  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  system.stateVersion = "26.05";
}
