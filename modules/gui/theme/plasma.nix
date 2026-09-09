{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.theme.plasma;
  themeCfg = config.features.gui.theme;
in {
  options.features.gui.theme.plasma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.theme.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        plasma-manager = {
          url = "github:nix-community/plasma-manager";
          inputs.nixpkgs.follows = "nixpkgs";
          inputs.home-manager.follows = "home-manager";
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        kdePackages.breeze
        kdePackages.breeze.qt5
        kdePackages.breeze-gtk
        kdePackages.breeze-icons
        hicolor-icon-theme
        libsForQt5.qtstyleplugin-kvantum
        kdePackages.qtstyleplugin-kvantum
      ];

      home-manager.users.cloudburst = {config, ...}: let
        renderUtils = import ../../../lib/helpers/jinja.nix {inherit pkgs config lib;};
        inherit (renderUtils) renderJinja2 cleanColors;

        kdeglobals = renderJinja2 "kdeglobals" ./_kdeglobals.j2 cleanColors;
        qtctColors = renderJinja2 "Stylix.conf" ./_qtct-colors.conf.j2 cleanColors;

        iconTheme =
          if themeCfg.polarity == "dark"
          then "breeze-dark"
          else "breeze";
        toRgb = key: "${config.lib.stylix.colors."${key}-rgb-r"},${config.lib.stylix.colors."${key}-rgb-g"},${
          config.lib.stylix.colors."${key}-rgb-b"
        }";
      in {
        stylix.targets.qt.enable = false;

        qt = {
          enable = true;
          # style.name = lib.mkForce "breeze";
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

        xdg.dataFile."color-schemes/Stylix.colors".source = kdeglobals;

        xdg.configFile = lib.mkMerge [
          {
            "color-schemes/Stylix.colors".source = kdeglobals;
            "qt5ct/colors/Stylix.conf".source = qtctColors;
            "qt6ct/colors/Stylix.conf".source = qtctColors;
          }
          (lib.mkIf (!config.programs.plasma.enable) {
            "kdeglobals".source = kdeglobals;
          })
        ];

        programs.plasma.configFile."kdeglobals" = {
          General = {
            ColorScheme = "Stylix";
            Name = "Stylix";
          };
          KDE = {
            widgetStyle = "Breeze";
          };
          UiSettings = {
            ColorScheme = "Stylix";
          };
          "ColorEffects:Disabled" = {
            ColorAmount = 0;
            ColorEffect = 0;
            ContrastAmount = "0.5";
            ContrastEffect = 1;
            IntensityAmount = 0;
            IntensityEffect = 0;
          };
          "ColorEffects:Inactive" = {
            ColorAmount = 0;
            ColorEffect = 0;
            ContrastAmount = "0.5";
            ContrastEffect = 1;
            IntensityAmount = 0;
            IntensityEffect = 0;
          };
          "Colors:Button" = {
            BackgroundAlternate = toRgb "base01";
            BackgroundNormal = toRgb "base00";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base05";
            ForegroundInactive = toRgb "base05";
            ForegroundLink = toRgb "base05";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base05";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base05";
          };
          "Colors:Complementary" = {
            BackgroundAlternate = toRgb "base01";
            BackgroundNormal = toRgb "base00";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base05";
            ForegroundInactive = toRgb "base05";
            ForegroundLink = toRgb "base05";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base05";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base05";
          };
          "Colors:Selection" = {
            BackgroundAlternate = toRgb "base0D";
            BackgroundNormal = toRgb "base0D";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base00";
            ForegroundInactive = toRgb "base00";
            ForegroundLink = toRgb "base00";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base00";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base00";
          };
          "Colors:Tooltip" = {
            BackgroundAlternate = toRgb "base01";
            BackgroundNormal = toRgb "base00";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base05";
            ForegroundInactive = toRgb "base05";
            ForegroundLink = toRgb "base05";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base05";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base05";
          };
          "Colors:View" = {
            BackgroundAlternate = toRgb "base01";
            BackgroundNormal = toRgb "base00";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base05";
            ForegroundInactive = toRgb "base05";
            ForegroundLink = toRgb "base05";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base05";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base05";
          };
          "Colors:Window" = {
            BackgroundAlternate = toRgb "base01";
            BackgroundNormal = toRgb "base00";
            DecorationFocus = toRgb "base0D";
            DecorationHover = toRgb "base0D";
            ForegroundActive = toRgb "base05";
            ForegroundInactive = toRgb "base05";
            ForegroundLink = toRgb "base05";
            ForegroundNegative = toRgb "base08";
            ForegroundNeutral = toRgb "base0D";
            ForegroundNormal = toRgb "base05";
            ForegroundPositive = toRgb "base0B";
            ForegroundVisited = toRgb "base05";
          };
          WM = {
            activeBackground = toRgb "base00";
            activeBlend = toRgb "base0A";
            activeForeground = toRgb "base05";
            inactiveBackground = toRgb "base00";
            inactiveBlend = toRgb "base03";
            inactiveForeground = toRgb "base05";
          };
        };

        home.sessionVariables = {
          KDE_COLOR_SCHEME_PATH = "${config.xdg.dataHome}/color-schemes/Stylix.colors";
          QS_ICON_THEME = iconTheme;
        };
      };
    })
  ];
}
