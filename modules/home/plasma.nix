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

      krunner = {
        shortcuts.launch = "Meta+Space";
      };
    };

    home.packages = [
    ];
  };
}
