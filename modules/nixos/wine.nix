{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.wine;
in {
  options.systemSettings.wine = {
    enable = lib.mkEnableOption "Enable Wine Windows compatibility layer";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable32Bit = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      wine-staging
      winetricks
      zenity
      cabextract
      p7zip
      unzip
    ];
  };
}
