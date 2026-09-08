{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.tools.organizeer;
in {
  options.features.gui.apps.tools.organizeer = lib.mkOption {
    type = lib.types.bool;
    default =
      (
        config.features.gui.enable
        && config.features.gui.apps.enable
        && config.features.gui.apps.tools.enable
      )
      && true;
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
    (lib.mkIf cfg {
      #inputs.organizeer.services.organizeer-daemon.enable = true;
      environment.systemPackages = lib.optionals (inputs ? organizeer && inputs.organizeer ? packages) [
        inputs.organizeer.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    })
  ];
}
