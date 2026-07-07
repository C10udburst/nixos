{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.wayvnc;
in {
  options.systemSettings.wayvnc = {
    enable = lib.mkEnableOption "Enable wayvnc VNC server running inside a Wayland session";

    windowManager = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.driftwm}/bin/driftwm-session";
      description = "Command used to launch the Wayland compositor/session that wayvnc attaches to.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.wayvnc];

    # systemd user service: wayvnc must run inside the Wayland session so it
    # can access the compositor socket.
    systemd.user.services.wayvnc = {
      description = "WayVNC — VNC server for Wayland compositors";

      after = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];

      environment = {
        WAYLAND_DISPLAY = "wayland-1";
        XDG_RUNTIME_DIR = "/run/user/%U";
      };

      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
        ExecStart = "${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
