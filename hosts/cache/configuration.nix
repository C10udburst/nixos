{inputs, ...}: {
  imports = [
    # Enabling this makes cache compile the kernel for surface go
    #inputs.nixos-hardware.nixosModules.microsoft-surface-go

    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  networking.hostName = "cache";

  system.stateVersion = "26.05";
}
