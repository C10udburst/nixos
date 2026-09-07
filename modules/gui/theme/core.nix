{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.theme;
in {
  options.features.gui.theme = {
    polarity = lib.mkOption {
      type = lib.types.enum [
        "dark"
        "light"
      ];
      default = "dark";
    };
  };

  config = lib.mkIf (config.features.gui.enable && cfg.enable) {
    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      kdePackages.breeze-icons
      hicolor-icon-theme
      libsForQt5.qtstyleplugin-kvantum
      kdePackages.qtstyleplugin-kvantum
    ];

    stylix = {
      enable = true;
      polarity = cfg.polarity;
      targets.gtksourceview.enable = false;
    };
  };
}
