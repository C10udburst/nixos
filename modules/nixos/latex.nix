{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.latex;
in {
  options.systemSettings.latex = {
    enable = lib.mkEnableOption "Enable LaTeX typesetting environment (scheme-medium)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      texlive.combined.scheme-medium
    ];
  };
}
