{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.greeter;
  greeterEnabled = config.features.gui.enable && cfg.enable;
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

  config = lib.mkIf cfg.enable {
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

    services.accounts-daemon.enable = true;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
