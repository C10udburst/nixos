{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.plasma;
in {
  options.homeSettings.plasma = {
    enable = lib.mkEnableOption "Enable KDE Plasma home-manager configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      workspace = {
        colorScheme = "BreezeDark";
        lookAndFeel = "org.kde.breezedark.desktop";
        iconTheme = "breeze-dark";
      };

      configFile = {
        "kwinrc" = {
          "org.kde.kdecoration2" = {
            "library" = "org.kde.klassy";
            "theme" = "org.kde.klassy";
          };
        };
        "kdeglobals" = {
          "KDE" = {
            "widgetStyle" = "klassy";
          };
        };
        "dolphinrc" = {
          "MainWindow" = {
            "MenuBar" = "Enabled";
          };
        };
        "konsolerc" = {
          "Desktop Entry" = {
            "DefaultProfile" = "JetBrainsMono.profile";
          };
          "KonsoleWindow" = {
            "ShowMenuBarByDefault" = true;
          };
        };
      };

      krunner = {
        shortcuts.launch = "Meta+Space";
      };
    };

    gtk = {
      gtk2.force = true; # some random file gets created and breaks home-manager if this is not set
      enable = true;
      theme = {
        name = "Breeze-Dark";
        package = pkgs.kdePackages.breeze-gtk;
      };
      iconTheme = {
        name = "breeze-dark";
        package = pkgs.kdePackages.breeze-icons;
      };
    };

    home.packages = [
      pkgs.klassy
    ];
  };
}
