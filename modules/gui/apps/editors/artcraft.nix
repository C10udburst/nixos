{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.editors.artcraft;
  editorsEnabled = config.features.gui.apps.editors.enable;

  craft = inputs.artcraft.packages.${pkgs.stdenv.hostPlatform.system};

  app = name: [
    craft.${name}
    craft.${name}.desktop
  ];
in {
  config = lib.mkMerge [
    {
      flake-file.inputs = {
        artcraft = {
          url = "github:mahlquistj/artcraft-flake";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages =
        lib.optionals cfg.gridcraft (app "gridcraft")
        ++ lib.optionals cfg.wordcraft (app "wordcraft")
        ++ lib.optionals cfg.deckcraft (app "deckcraft");
    })
  ];

  options.features.gui.apps.editors.artcraft = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = editorsEnabled && true;
    };

    gridcraft = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };

    wordcraft = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };

    deckcraft = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };
  };
}
