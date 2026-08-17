{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.systemSettings.greetd;

  westonIni = pkgs.writeText "weston.ini" ''
    [core]
    shell=kiosk-shell.so
    ${lib.optionalString (config.systemSettings.touchscreen.enable or false) ''

      [input-method]
      path=${pkgs.weston}/libexec/weston-keyboard''}

    [shell]
    quit-when-apps-close=true
  '';
  greetdSessionScript = pkgs.writeShellScript "greetd-session" ''
    ${lib.optionalString (config.systemSettings.touchscreen.enable or false) "auto-rotate &"}
    exec ${config.programs.regreet.package}/bin/regreet
  '';
in
{
  options.systemSettings.greetd = {
    enable = lib.mkEnableOption "Enable greetd with ReGreet display manager";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = lib.mkForce "${pkgs.coreutils}/bin/env GSK_RENDERER=ngl ${pkgs.weston}/bin/weston --config=${westonIni} -- ${greetdSessionScript}";
            user = "greeter";
          };
        };
      };

      users.users.greeter = {
        home = "/var/lib/greetd";
        createHome = true;
      };

      programs.regreet = {
        enable = true;
        settings = {
          widget.clock = {
            format = "%a %H:%M";
            timezone = config.time.timeZone;
            locale = config.i18n.defaultLocale;
          };
        };
      };

      services.accounts-daemon.enable = true;
      services.displayManager.sddm.enable = lib.mkForce false;
      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

      systemd.services.greetd.environment = {
        GSK_RENDERER = "ngl";
      };
    })
    (lib.mkIf (!cfg.enable) {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
    })
  ];
}
