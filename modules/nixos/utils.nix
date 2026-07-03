{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.utils;
in {
  options.systemSettings.utils = {
    enable = lib.mkEnableOption "Enable modern CLI utilities (eza, bat, fd, ripgrep, procs, dust, fzf)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      eza
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
    ];
  };
}
