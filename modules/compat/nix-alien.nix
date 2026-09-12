{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.compat.nix-alien;
in {
  options.features.compat.nix-alien = lib.mkOption {
    type = lib.types.bool;
    default = config.features.compat.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        nix-alien = {
          url = "github:thiagokokada/nix-alien";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = lib.optionals (
        inputs ? nix-alien
        && inputs.nix-alien ? packages
        && inputs.nix-alien.packages ? ${pkgs.stdenv.hostPlatform.system}
      ) [
        inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.nix-alien
      ];
    })
  ];
}
