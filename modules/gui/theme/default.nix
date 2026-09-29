{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.theme;
  isSlow = config.features.core.hardware.slow or false;

  wallpaper =
    if cfg.wallpaper != null
    then
      if isSlow
      then
        pkgs.runCommand "scaled-wallpaper.jpg" {
          nativeBuildInputs = [pkgs.imagemagick];
        } ''
          magick "${cfg.wallpaper}" -quality 50% -resize 75% "$out"
        ''
      else cfg.wallpaper
    else null;
in {
  options.features.gui.theme = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.package);
      default = null;
    };
  };

  config = lib.mkIf (cfg.enable && wallpaper != null) {
    stylix.image = wallpaper;
  };
}
