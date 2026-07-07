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
      default = "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11";
      description = "Session command xrdp launches for each connection. Must be an X11 session (startplasma-wayland does not work reliably with xrdp).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xrdp = {
      enable = true;
      defaultWindowManager = cfg.windowManager;
      openFirewall = true;
      audio.enable = true;
    };
  };
}
