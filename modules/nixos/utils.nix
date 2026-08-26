{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.utils;
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
  options.systemSettings.utils = {
    enable = lib.mkEnableOption "Enable modern CLI utilities (eza, bat, fd, ripgrep, procs, dust, fzf)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bat
      fd
      ripgrep
      procs
      dust
      fzf
      hexyl
      binwalk
      asciinema
      qrencode
      zbar
      ranger
      kimsay
      jless
    ];
  };
}
