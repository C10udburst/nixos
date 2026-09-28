{...}: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  networking.hostName = "zeph";

  system.stateVersion = "26.05";
}
