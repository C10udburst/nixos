{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter;
  hasAutologin = (cfg.autologin or null) != null && (cfg.autologin or false) != false;
  useSddm = (cfg.sddm or false) && !hasAutologin;
in {
  options.features.gui.greeter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.accounts-daemon.enable = true;
      services.gnome.gnome-keyring.enable = true;
    }
    (lib.mkIf (!useSddm) {
      services.greetd = {
        enable = true;
        settings = {
          default_session = lib.mkDefault {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session";
            user = "greeter";
          };
        };
      };

      users.users.greeter = {
        home = "/var/lib/greetd";
        createHome = true;
      };

      services.displayManager.sddm.enable = lib.mkForce false;
      security.pam.services.greetd.enableGnomeKeyring = true;
    })
  ]);
}
