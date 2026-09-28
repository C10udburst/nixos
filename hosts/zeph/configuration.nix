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

  # asusd systemd service requires /etc/asusd to exist for ReadWritePaths mount namespacing
  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
  ];

  environment.systemPackages = with pkgs; [
    asusctl
    supergfxctl
  ];

  system.stateVersion = "26.05";
}
