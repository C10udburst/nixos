{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.features.gui.apps.tools.organizeer;
in
{
  imports = lib.optionals (inputs ? organizeer && inputs.organizeer ? nixosModules) [
    inputs.organizeer.nixosModules.default
  ];

  options.features.gui.apps.tools.organizeer = lib.mkOption {
    type = lib.types.bool;
    default = config.features.gui.apps.tools.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        organizeer = {
          url = "git+ssh://git@github.com/C10udburst/Organizeer.git";
          #inputs.nixpkgs.follows = "nixpkgs"; #breaks gradle lock
        };
      };
    }
    (lib.mkIf (cfg && inputs ? organizeer && inputs.organizeer ? nixosModules) {
      services.organizeer-daemon.enable = true;
    })
    (lib.mkIf cfg {
      environment.systemPackages = lib.optionals (inputs ? organizeer && inputs.organizeer ? packages) [
        inputs.organizeer.packages.${pkgs.stdenv.hostPlatform.system}.app
      ];
    })
  ];
}
