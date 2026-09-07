{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.organizeer;
  toolsEnabled =
    config.features.gui.enable
    && config.features.gui.apps.enable
    && config.features.gui.apps.tools.enable;
in {
  imports = lib.optionals (inputs ? organizeer && inputs.organizeer ? nixosModules) [
    inputs.organizeer.nixosModules.default
  ];

  options.features.gui.apps.tools.organizeer = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        organizeer = {
          url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf (toolsEnabled && cfg) {
      services.organizeer-daemon.enable = true;
      environment.systemPackages = lib.optionals (inputs ? organizeer && inputs.organizeer ? packages) [
        inputs.organizeer.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    })
  ];
}
