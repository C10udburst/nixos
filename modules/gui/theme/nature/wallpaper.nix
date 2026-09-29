{
  config,
  lib,
  ...
}: let
  cfg = config.features.gui.theme.nature.wallpaper;
  parentEnabled = config.features.gui.theme.nature.enable;
in {
  options.features.gui.theme.nature.wallpaper = lib.mkOption {
    type = lib.types.bool;
    default = parentEnabled && true;
  };

  config = lib.mkIf cfg {
    # Ernst Haeckel Artforms of Nature
    features.gui.theme.wallpaper = lib.mkDefault ./_wallpaper.jpg;
  };
}
