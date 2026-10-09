{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.social.zapfast;
  socialEnabled = config.features.gui.apps.tools.social.enable;
in {
  options.features.gui.apps.tools.social.zapfast = lib.mkOption {
    type = lib.types.bool;
    default = socialEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        zapfast = {
          url = "github:crmne/zapfast";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = [
        inputs.zapfast.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    })
  ];
}
