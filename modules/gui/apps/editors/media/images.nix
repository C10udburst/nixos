{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.editors.media.images;
in {
  options.features.gui.apps.editors.media.images = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.apps.editors.media.enable && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      (gimp3-with-plugins.override {
        plugins = with pkgs.gimp3Plugins; [
          resynthesizer
        ];
      })
      inkscape
      imagemagick
    ];
  };
}
