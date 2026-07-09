{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.wayvnc;

  greetdWayvncWrapper = pkgs.writeShellScript "greetd-wayvnc-wrapper" ''
    # Wait for the Wayland socket created by Cage
    for i in {1..20}; do
      if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900 &
        break
      fi
      sleep 0.1
    done
    exec ${config.programs.regreet.package}/bin/regreet
  '';

  headlessGreetdConfig = pkgs.writeText "greetd-headless.toml" ''
    [general]
    run_directory = "/run/greetd-headless"

    [terminal]
    vt = 8

    [default_session]
    command = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.cage}/bin/cage -s -m last -d -- ${greetdWayvncWrapper}"
    user = "greeter"
  '';
in {
  options.systemSettings.wayvnc = {
    enable = lib.mkEnableOption "Enable wayvnc VNC server running inside a Wayland/greetd session";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.wayvnc];

    networking.firewall.allowedTCPPorts = [5900];

    # Setup the PAM service for greetd if not already present
    security.pam.services.greetd = {};

    # Run a separate, concurrent greetd instance in headless mode
    systemd.services.greetd-headless = {
      description = "Headless greetd Login Manager";
      after = ["network.target" "dbus.socket" "systemd-user-sessions.service" "plymouth-quit-active.service" "getty@tty8.service"];
      wants = ["dbus.socket" "systemd-user-sessions.service"];
      wantedBy = ["multi-user.target"];

      environment = {
        WLR_BACKENDS = "headless";
        WLR_LIBINPUT_NO_DEVICES = "1";
      };

      serviceConfig = {
        ExecStart = "${pkgs.greetd}/bin/greetd --config ${headlessGreetdConfig}";
        Restart = "always";
        RestartSec = "1s";
        RuntimeDirectory = "greetd-headless";
        RuntimeDirectoryMode = "0755";
      };
    };

    # systemd user service for wayvnc inside the logged-in user session
    systemd.user.services.wayvnc = {
      description = "WayVNC — VNC server for Wayland compositors";

      after = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];

      # Let wayvnc inherit WAYLAND_DISPLAY from systemd user manager environment.
      environment = {
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
