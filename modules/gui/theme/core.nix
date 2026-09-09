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

      qt = {
        enable = true;
        style = lib.mkForce "breeze";
      };

      stylix = {
        enable = true;
        inherit (cfg) polarity;
        targets.gtksourceview.enable = false;
        targets.qt.enable = true;
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
