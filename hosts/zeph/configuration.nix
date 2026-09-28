{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401
    ./hardware-configuration.nix
    ./home-manager.nix
    ./features.nix
  ];

  networking.hostName = "zeph";

  services.asusd.enable = true;

  environment.systemPackages = with pkgs; [
    asusctl
    supergfxctl
  ];

  system.stateVersion = "26.05";
}
