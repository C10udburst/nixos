{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.typst;
in {
  options.systemSettings.typst = {
    enable = lib.mkEnableOption "Enable Typst typesetting environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      typst
      typstyle
    ];
  };
}
