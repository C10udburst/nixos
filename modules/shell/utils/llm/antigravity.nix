{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.llm.antigravity;
  llmEnabled = config.features.shell.utils.llm.enable;
in {
  options.features.shell.utils.llm.antigravity = lib.mkOption {
    type = lib.types.bool;
    default = llmEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        antigravity-nix = {
          url = "github:jacopone/antigravity-nix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages =
        lib.optionals
        (
          inputs ? antigravity-nix
          && inputs.antigravity-nix ? packages
          && inputs.antigravity-nix.packages ? ${pkgs.stdenv.hostPlatform.system}
        )
        [
          #inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
          inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
        ];
    })
  ];
}
