{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.theme.wallpaper;
in {
  options.features.gui.theme.wallpaper = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if (config.features.gui.enable && config.features.gui.theme.enable)
        then true
        else false;
    };
  };

  config = lib.mkIf (config.features.gui.enable && config.features.gui.theme.enable && cfg.enable) {
    stylix.image = ./_wallpaper.jpg;
  };
}
