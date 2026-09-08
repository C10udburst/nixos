{...}: {
  imports = [
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  networking.hostName = "bootstrap-host";

  system.stateVersion = "26.05";
}
