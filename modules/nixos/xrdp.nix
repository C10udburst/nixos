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

    windowManager = lib.mkOption {
      type = lib.types.str;
      default = "startplasma-x11";
      description = "Session command xrdp launches for each connection. Launches plasma x11";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xrdp = {
      enable = true;
      defaultWindowManager = cfg.windowManager;
      openFirewall = true;
      audio.enable = true;
    };

    programs.regreet.enable = true;
  };
}
