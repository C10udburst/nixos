{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter.greetd;
  autologinCommand =
    if cfg.defaultSession == "driftwm"
    then "${pkgs.driftwm}/bin/driftwm-session"
    else if cfg.defaultSession == "plasma"
    then "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland"
    else "${pkgs.driftwm}/bin/driftwm-session";

  westonIni = pkgs.writeText "weston.ini" ''
    [core]
    shell=kiosk-shell.so
    ${lib.optionalString (config.features.core.hardware.touchscreen or false) ''
      [input-method]
      path=${pkgs.weston}/libexec/weston-keyboard''}

    [shell]
    quit-when-apps-close=true
  '';

  greetdSessionScript = pkgs.writeShellScript "greetd-session" ''
    ${lib.optionalString (config.features.core.hardware.touchscreen or false) "auto-rotate &"}
    exec ${config.programs.regreet.package}/bin/regreet
  '';
in {
  options.features.gui.greeter.greetd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if (config.features.gui.enable && config.features.gui.greeter.enable)
        then true
        else false;
    };
    autologin = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    defaultSession = lib.mkOption {
      type = lib.types.str;
      default = "driftwm";
    };
  };

  config = lib.mkIf (config.features.gui.enable && config.features.gui.greeter.enable && cfg.enable) {
    services.greetd = {
      enable = true;
      settings = {
        default_session =
          if cfg.autologin
          then {
            command = autologinCommand;
            user = "cloudburst";
          }
          else {
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
  };
}
