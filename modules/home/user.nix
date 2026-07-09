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

    gtk = {
      enable = true;
      gtk2.force = true; # some random file gets created and breaks home-manager if this is not set
      iconTheme = {
        # Adwaita ships window-close-symbolic / window-minimize-symbolic etc.
        # in the hicolor-compatible path GTK expects for CSD title bars.
        # breeze-dark (a KDE theme) misses these outside a full Plasma session,
        # causing Inkscape / GIMP close+minimize icons to show as missing.
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };
}
