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

    home.packages = [
      pkgs.klassy
      pkgs.kdePackages.karousel
    ];
  };
}
