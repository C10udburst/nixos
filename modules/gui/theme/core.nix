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
        colors = config.lib.stylix.colors;
        iconTheme =
          if cfg.polarity == "dark"
          then "breeze-dark"
          else "breeze";

        kdeglobalsContent = ''
          [General]
          ColorScheme=Stylix
          Name=Stylix

          [KDE]
          widgetStyle=Breeze

          [UiSettings]
          ColorScheme=Stylix

          [ColorEffects:Disabled]
          ColorAmount=0
          ColorEffect=0
          ContrastAmount=0.5
          ContrastEffect=1
          IntensityAmount=0
          IntensityEffect=0

          [ColorEffects:Inactive]
          ColorAmount=0
          ColorEffect=0
          ContrastAmount=0.5
          ContrastEffect=1
          IntensityAmount=0
          IntensityEffect=0

          [Colors:Button]
          BackgroundAlternate=${colors.base01-rgb-r},${colors.base01-rgb-g},${colors.base01-rgb-b}
          BackgroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundInactive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundLink=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}

          [Colors:Complementary]
          BackgroundAlternate=${colors.base01-rgb-r},${colors.base01-rgb-g},${colors.base01-rgb-b}
          BackgroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundInactive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundLink=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}

          [Colors:Selection]
          BackgroundAlternate=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          BackgroundNormal=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          ForegroundInactive=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          ForegroundLink=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}

          [Colors:Tooltip]
          BackgroundAlternate=${colors.base01-rgb-r},${colors.base01-rgb-g},${colors.base01-rgb-b}
          BackgroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundInactive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundLink=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}

          [Colors:View]
          BackgroundAlternate=${colors.base01-rgb-r},${colors.base01-rgb-g},${colors.base01-rgb-b}
          BackgroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundInactive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundLink=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}

          [Colors:Window]
          BackgroundAlternate=${colors.base01-rgb-r},${colors.base01-rgb-g},${colors.base01-rgb-b}
          BackgroundNormal=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          DecorationFocus=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          DecorationHover=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundActive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundInactive=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundLink=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundNegative=${colors.base08-rgb-r},${colors.base08-rgb-g},${colors.base08-rgb-b}
          ForegroundNeutral=${colors.base0D-rgb-r},${colors.base0D-rgb-g},${colors.base0D-rgb-b}
          ForegroundNormal=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          ForegroundPositive=${colors.base0B-rgb-r},${colors.base0B-rgb-g},${colors.base0B-rgb-b}
          ForegroundVisited=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}

          [WM]
          activeBackground=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          activeBlend=${colors.base0A-rgb-r},${colors.base0A-rgb-g},${colors.base0A-rgb-b}
          activeForeground=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
          inactiveBackground=${colors.base00-rgb-r},${colors.base00-rgb-g},${colors.base00-rgb-b}
          inactiveBlend=${colors.base03-rgb-r},${colors.base03-rgb-g},${colors.base03-rgb-b}
          inactiveForeground=${colors.base05-rgb-r},${colors.base05-rgb-g},${colors.base05-rgb-b}
        '';

        qtctColors = ''
          [ColorScheme]
          active_colors=#ff${colors.base05}, #ff${colors.base00}, #ff${colors.base02}, #ff${colors.base01}, #ff${colors.base00}, #ff${colors.base01}, #ff${colors.base05}, #ff${colors.base07}, #ff${colors.base05}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base0D}, #ff${colors.base00}, #ff${colors.base0D}, #ff${colors.base0E}, #ff${colors.base01}, #ff000000, #ff${colors.base01}, #ff${colors.base05}, #80${colors.base05}
          disabled_colors=#ff${colors.base03}, #ff${colors.base00}, #ff${colors.base02}, #ff${colors.base01}, #ff${colors.base00}, #ff${colors.base01}, #ff${colors.base03}, #ff${colors.base07}, #ff${colors.base03}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base0D}, #ff${colors.base03}, #ff${colors.base0D}, #ff${colors.base0E}, #ff${colors.base01}, #ff000000, #ff${colors.base01}, #ff${colors.base03}, #80${colors.base03}
          inactive_colors=#ff${colors.base05}, #ff${colors.base00}, #ff${colors.base02}, #ff${colors.base01}, #ff${colors.base00}, #ff${colors.base01}, #ff${colors.base05}, #ff${colors.base07}, #ff${colors.base05}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base00}, #ff${colors.base0D}, #ff${colors.base00}, #ff${colors.base0D}, #ff${colors.base0E}, #ff${colors.base01}, #ff000000, #ff${colors.base01}, #ff${colors.base05}, #80${colors.base05}
        '';
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

        xdg.configFile."kdeglobals".text = kdeglobalsContent;
        xdg.configFile."color-schemes/Stylix.colors".text = kdeglobalsContent;
        xdg.configFile."qt5ct/colors/Stylix.conf".text = qtctColors;
        xdg.configFile."qt6ct/colors/Stylix.conf".text = qtctColors;

        home.sessionVariables = {
          KDE_COLOR_SCHEME_PATH = "${config.xdg.configHome}/color-schemes/Stylix.colors";
          QS_ICON_THEME = iconTheme;
        };
      };
    })
  ];
}
