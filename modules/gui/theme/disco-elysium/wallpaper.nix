{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.theme.disco-elysium.wallpaper;
in {
  options.features.gui.theme.disco-elysium.wallpaper = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.theme.disco-elysium.enable && true;
  };

  config = lib.mkIf cfg {
    features.gui.theme.wallpaper = lib.mkDefault ./_wallpaper.jpg;
  };
}
