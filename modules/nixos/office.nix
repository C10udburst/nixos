{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.office;
in {
  options.systemSettings.office = {
    enable = lib.mkEnableOption "Enable office suite (LibreOffice)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libreoffice-qt
      karp
    ];
  };
}
