{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.user;
in {
  options.homeSettings.user = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "cloudburst";
      description = "The username";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.homeSettings.user.username}";
      description = "The home directory";
    };
  };

  config = {
    home.username = cfg.username;
    home.homeDirectory = cfg.homeDirectory;
    programs.home-manager.enable = true;

    systemd.user.sessionVariables = {
      JAVA_HOME = "/run/current-system/sw/lib/openjdk";
      ANDROID_HOME = "/run/current-system/sw/libexec/android-sdk";
      ANDROID_SDK_ROOT = "/run/current-system/sw/libexec/android-sdk";
    };

    gtk = {
      enable = true;
      gtk2.force = true; # some random file gets created and breaks home-manager if this is not set
      iconTheme = {
        name = "breeze-dark";
        package = pkgs.kdePackages.breeze-icons;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    qt.enable = true;

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
      QT_QPA_PLATFORM = "wayland;xcb";
      QS_ICON_THEME = "breeze-dark";
    };

    xdg.configFile."kdeglobals".text = ''
      [General]
      ColorScheme=BreezeDark
      Name=Breeze Dark

      [Icons]
      Theme=breeze-dark
    '';

    # # Configure Konsole to use JetBrains Mono Nerd Font
    # home.file.".local/share/konsole/JetBrainsMono.profile".text = ''
    #   [Appearance]
    #   Font=JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0

    #   [General]
    #   Name=JetBrainsMono
    #   Parent=FALLBACK/
    # '';

    # home.activation.removeExistingKonsolerc = lib.hm.dag.entryBefore ["writeBoundary"] ''
    #   if [ -L "$HOME/.config/konsolerc" ]; then
    #     rm -f "$HOME/.config/konsolerc"
    #   fi
    # '';
  };
}
