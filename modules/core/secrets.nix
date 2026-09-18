{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.core.secrets;
in {
  options.features.core.secrets = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.core.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        agenix = {
          url = "github:ryantm/agenix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages =
        lib.optionals
        (
          inputs ? agenix
          && inputs.agenix ? packages
          && inputs.agenix.packages ? ${pkgs.stdenv.hostPlatform.system}
        )
        [
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        ]
        ++ [
          pkgs.age
        ];
    })
  ];
}
