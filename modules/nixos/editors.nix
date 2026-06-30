{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.editors;
in {
  options.systemSettings.editors = {
    enable = lib.mkEnableOption "Enable graphical editors (GIMP, Inkscape, Kdenlive, Audacity)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gimp3-with-plugins
      inkscape
      kdePackages.kdenlive
      audacity
      imagemagick
    ];
  };
}
