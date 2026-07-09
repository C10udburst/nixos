{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.xrdp;

  westonIni = pkgs.writeText "weston.ini" ''
    [core]
    shell=kiosk-shell.so

    [shell]
    quit-when-apps-close=true
  '';
in {
  options.systemSettings.xrdp = {
    enable = lib.mkEnableOption "Enable xrdp Remote Desktop daemon";

    windowManager = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.coreutils}/bin/env GSK_RENDERER=ngl ${pkgs.weston}/bin/weston --config=${westonIni} -- ${config.programs.regreet.package}/bin/regreet";
      description = "Session command xrdp launches for each connection. Launches Weston with ReGreet.";
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
