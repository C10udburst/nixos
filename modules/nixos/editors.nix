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
      (pkgs.gimp3-with-plugins.override {
        plugins = with pkgs.gimp3Plugins; [
          #gimpPlugins.fourier
          #gimpPlugins.gmic
          gimpPlugins.resynthesizer
          #gimpPlugins.waveletSharpen
          #gimpPlugins.lqrPlugin
        ];
      })
      inkscape
      kdePackages.kdenlive
      audacity
      imagemagick
    ];
  };
}
