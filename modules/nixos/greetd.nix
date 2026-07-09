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
    programs.regreet = {
      enable = true;
      cageArgs = ["-s" "-m" "last"];
    };
    services.accounts-daemon.enable = true;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
