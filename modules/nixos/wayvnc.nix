{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.wayvnc;
  allUsers = lib.unique (config.systemSettings.users ++ config.systemSettings.adminUsers);
  isHeadless = cfg.session == "headless";
  headlessSwayConfig = pkgs.writeText "sway-headless.config" ''
    # Minimal headless Sway configuration
    output HEADLESS-1 resolution 1920x1080

    # Run the default driftwm window manager session
    exec ${pkgs.driftwm}/bin/driftwm-session
  '';
in {
  options.systemSettings.wayvnc = {
    enable = lib.mkEnableOption "Enable wayvnc VNC server running inside a Wayland session";

    session = lib.mkOption {
      type = lib.types.enum ["greetd" "headless"];
      default = "greetd";
      description = "The type of display/compositor session wayvnc attaches to.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.wayvnc] ++ lib.optional isHeadless pkgs.sway;

    networking.firewall.allowedTCPPorts = [5900];

    users.users = lib.mkIf isHeadless (
      lib.genAttrs allUsers (username: {
        linger = true;
      })
    );

    # systemd user services
    systemd.user.services = {
      # Headless Sway compositor service
      sway-headless = lib.mkIf isHeadless {
        description = "Headless Sway compositor for wayvnc";
        before = ["wayvnc.service"];
        after = ["graphical-session-pre.target"];
        wants = ["graphical-session-pre.target"];
        wantedBy = ["default.target"];

        environment = {
          WLR_BACKENDS = "headless";
          WLR_LIBINPUT_NO_DEVICES = "1";
          WAYLAND_DISPLAY = "wayland-1";
          XDG_RUNTIME_DIR = "/run/user/%U";
        };

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.sway}/bin/sway -c ${headlessSwayConfig} -s wayland-1";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # WayVNC VNC server service
      wayvnc = {
        description = "WayVNC — VNC server for Wayland compositors";

        # In headless mode, wayvnc starts after sway-headless.
        # Otherwise, it starts after graphical-session.target.
        after =
          if isHeadless
          then ["sway-headless.service"]
          else ["graphical-session.target"];
        wants =
          if isHeadless
          then ["sway-headless.service"]
          else ["graphical-session.target"];
        wantedBy =
          if isHeadless
          then ["default.target"]
          else ["graphical-session.target"];

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
  };
}
