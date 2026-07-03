{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.xrdp;
in {
  options.systemSettings.xrdp = {
    enable = lib.mkEnableOption "Enable xrdp Remote Desktop daemon";
  };

  config = lib.mkIf cfg.enable {
    services.xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.driftwm}/bin/driftwm";
      openFirewall = true;
      audio.enable = true;
    };
  };
}
