{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter;
  greeterEnabled = cfg.enable;
  hasAutologin = (cfg.autologin or null) != null && (cfg.autologin or false) != false;

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
  options.features.gui.greeter.regreet = lib.mkOption {
    type = lib.types.bool;
    default = greeterEnabled && false;
  };

  config = lib.mkIf (cfg.enable && cfg.regreet && !hasAutologin && !(cfg.sddm.enable or false)) {
    services.greetd.settings.default_session = {
      command = lib.mkForce "${pkgs.coreutils}/bin/env GSK_RENDERER=ngl ${pkgs.weston}/bin/weston --config=${westonIni} -- ${greetdSessionScript}";
      user = "greeter";
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

    systemd.services.greetd.environment = {
      GSK_RENDERER = "ngl";
    };
  };
}
