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
        name = "breeze-dark";
        package = pkgs.kdePackages.breeze-icons;
      };
    };

    # Configure Konsole to use JetBrains Mono Nerd Font
    home.file.".local/share/konsole/JetBrainsMono.profile".text = ''
      [Appearance]
      Font=JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0

      [General]
      Name=JetBrainsMono
      Parent=FALLBACK/
    '';

    home.activation.removeExistingKonsolerc = lib.hm.dag.entryBefore ["writeBoundary"] ''
      if [ -L "$HOME/.config/konsolerc" ]; then
        rm -f "$HOME/.config/konsolerc"
      fi
    '';
  };
}
