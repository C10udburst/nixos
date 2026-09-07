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
    default =
      if (config.features.shell.enable && config.features.shell.utils.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.utils.enable && cfg) {
    environment.systemPackages = with pkgs; [
      fastfetch
      kimsay
      asciinema
    ];
  };
}
