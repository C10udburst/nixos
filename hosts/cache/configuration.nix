{...}: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  networking.hostName = "cache";

  system.stateVersion = "26.05";
}
