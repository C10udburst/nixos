{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.gaming;
in {
  options.systemSettings.gaming = {
    enable = lib.mkEnableOption "Enable gaming tools and programs";
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      protonup-qt
      lutris
      heroic
      mangohud
    ];
  };
}
