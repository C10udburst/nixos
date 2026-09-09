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

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        stylix = {
          url = "github:nix-community/stylix/release-26.05";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      programs.dconf.enable = true;

      environment.systemPackages = with pkgs; [
        kdePackages.breeze
        kdePackages.breeze.qt5
        kdePackages.breeze-gtk
        kdePackages.breeze-icons
        hicolor-icon-theme
        libsForQt5.qtstyleplugin-kvantum
        kdePackages.qtstyleplugin-kvantum
      ];

      qt = {
        enable = true;
        style = "breeze";
      };

      stylix = {
        enable = true;
        inherit (cfg) polarity;
        targets.gtksourceview.enable = false;
        targets.qt.enable = false;
      };

      home-manager.users.cloudburst = {config, ...}: let
        renderUtils = import ../../../lib/helpers/jinja.nix {inherit pkgs config lib;};
        inherit (renderUtils) renderJinja2 cleanColors;

        kdeglobals = renderJinja2 "kdeglobals" ./_kdeglobals.j2 cleanColors;
        qtctColors = renderJinja2 "Stylix.conf" ./_qtct-colors.conf.j2 cleanColors;

        iconTheme =
          if cfg.polarity == "dark"
          then "breeze-dark"
          else "breeze";
      in {
        stylix.targets.qt.enable = false;

        qt = {
          enable = true;
          style.name = lib.mkForce "breeze";
          style.package = with pkgs; [
            kdePackages.breeze
            kdePackages.breeze.qt5
          ];
          platformTheme.name = lib.mkDefault "qtct";
          qt5ctSettings = {
            Appearance = {
              style = "Breeze";
              icon_theme = iconTheme;
              standard_dialogs = "default";
              custom_palette = true;
              color_scheme_path = "${config.xdg.configHome}/qt5ct/colors/Stylix.conf";
            };
          };
          qt6ctSettings = {
            Appearance = {
              style = "Breeze";
              icon_theme = iconTheme;
              standard_dialogs = "default";
              custom_palette = true;
              color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/Stylix.conf";
            };
          };
        };

        xdg.configFile."color-schemes/Stylix.colors".source = kdeglobals;
        xdg.configFile."qt5ct/colors/Stylix.conf".source = qtctColors;
        xdg.configFile."qt6ct/colors/Stylix.conf".source = qtctColors;

        home.sessionVariables = {
          KDE_COLOR_SCHEME_PATH = "${config.xdg.configHome}/color-schemes/Stylix.colors";
          QS_ICON_THEME = iconTheme;
        };
      };
    })
  ];
}
