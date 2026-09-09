{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.utils.fun;
  kimsay = pkgs.stdenv.mkDerivation {
    pname = "kimsay";
    version = "master";
    src = inputs.kimsay;
    makeFlags = ["PREFIX=$(out)"];
  };
in {
  options.features.shell.utils.fun = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.utils.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        kimsay = {
          url = "github:IcaroJam/kimsay";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = with pkgs; [
        fastfetch
        kimsay
        asciinema
      ];
    })
  ];
}
