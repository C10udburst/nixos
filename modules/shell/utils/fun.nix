{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.fun;
  kimsay = pkgs.stdenv.mkDerivation {
    pname = "kimsay";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "IcaroJam";
      repo = "kimsay";
      rev = "86cc051aa35dccb1a924c6cc551a1f2f4871d93b";
      sha256 = "sha256-YQrchMAONHOqwy+CeZ5WEmJgNpd+ZbDGlMM/RVPxOvI=";
    };
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
      cowsay
      kimsay
    ];
  };
}
