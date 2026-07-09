{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.greetd;
in {
  options.systemSettings.greetd = {
    enable = lib.mkEnableOption "Enable greetd with ReGreet display manager";
  };

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
    };

    users.users.greeter = {
      home = "/var/lib/greetd";
      createHome = true;
    };

    programs.regreet = {
      enable = true;
      cageArgs = ["-d" "-m" "last"];
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
  };
}
