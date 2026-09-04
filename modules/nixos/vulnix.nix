{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.vulnix;
in {
  options.systemSettings.vulnix = {
    enable = lib.mkEnableOption "Enable vulnix NixOS vulnerability scanner";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vulnix
    ];
  };
}
