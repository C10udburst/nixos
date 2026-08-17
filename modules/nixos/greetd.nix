{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.systemSettings.greetd;

  defaultUser =
    if config.hostSettings ? username then
      config.hostSettings.username
    else if (config.systemSettings.users or [ ]) != [ ] then
      builtins.head config.systemSettings.users
    else
      "cloudburst";

  autologinCommand =
    if config.systemSettings.driftwm.enable or false then
      "${pkgs.driftwm}/bin/driftwm-session"
    else if config.systemSettings.plasma.enable or false then
      "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland"
    else
      "${pkgs.driftwm}/bin/driftwm-session";

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
    enable = lib.mkEnableOption "Enable greetd display manager";
    autologin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable autologin to default session (driftwm or plasma)";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.greetd = {
        enable = true;
        settings = {
          default_session =
            if cfg.autologin then
              {
                command = autologinCommand;
                user = defaultUser;
              }
            else
              {
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
        enable = !cfg.autologin;
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
  ];
}
