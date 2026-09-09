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
        kdePackages.breeze-icons
        hicolor-icon-theme
        libsForQt5.qtstyleplugin-kvantum
        kdePackages.qtstyleplugin-kvantum
      ];

      stylix = {
        enable = true;
        inherit (cfg) polarity;
        targets.gtksourceview.enable = false;
        icons = {
          enable = true;
          package = pkgs.kdePackages.breeze-icons;
          dark = "breeze-dark";
          light = "breeze";
        };
      };
    })
  ];
}
