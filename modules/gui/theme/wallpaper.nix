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
      default = config.features.gui.theme.enable && true;
    };
  };

  config = lib.mkIf cfg.enable {
    stylix.image = ./_wallpaper.jpg;
  };
}
