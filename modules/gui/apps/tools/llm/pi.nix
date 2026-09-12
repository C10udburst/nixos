{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.llm.pi;
  llmEnabled = config.features.gui.apps.tools.llm.enable;
in {
  options.features.gui.apps.tools.llm.pi = lib.mkOption {
    type = lib.types.bool;
    default = llmEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        pi-agent = {
          url = "github:lukasl-dev/pi.nix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = lib.optionals (
        inputs ? pi-agent
        && inputs.pi-agent ? packages
        && inputs.pi-agent.packages ? ${pkgs.stdenv.hostPlatform.system}
      ) [inputs.pi-agent.packages.${pkgs.stdenv.hostPlatform.system}.default];
    })
  ];
}
