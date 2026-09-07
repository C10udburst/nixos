{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter;
  greeterEnabled = config.features.gui.enable && cfg.enable;
  hasAutologin = cfg.autologin != null && cfg.autologin != false;

  autologinCommand =
    if cfg.autologin == "driftwm"
    then "${pkgs.driftwm}/bin/driftwm-session"
    else if cfg.autologin == "plasma"
    then "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland"
    else toString cfg.autologin;

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
  options.features.gui.greeter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
    regreet = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    autologin = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.str lib.types.bool);
      default = null;
    };
  };

  config = lib.mkIf greeterEnabled {
    services.greetd = {
      enable = true;
      settings = {
        default_session =
          if hasAutologin
          then {
            command = autologinCommand;
            user = "cloudburst";
          }
          else if cfg.regreet
          then {
            command = lib.mkForce "${pkgs.coreutils}/bin/env GSK_RENDERER=ngl ${pkgs.weston}/bin/weston --config=${westonIni} -- ${greetdSessionScript}";
            user = "greeter";
          }
          else {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session";
            user = "greeter";
          };
      };
    };

    users.users.greeter = {
      home = "/var/lib/greetd";
      createHome = true;
    };

    programs.regreet = lib.mkIf (!hasAutologin && cfg.regreet) {
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

    systemd.services.greetd.environment = lib.mkIf (!hasAutologin && cfg.regreet) {
      GSK_RENDERER = "ngl";
    };
  };
}
