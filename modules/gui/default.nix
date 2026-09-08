{
  config,
  lib,
  pkgs,
  ...
}: {
  options.features.gui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf config.features.gui.enable {
    environment.systemPackages = [
      pkgs.seahorse
    ];

    services.gnome.gnome-keyring.enable = lib.mkDefault true;

    home-manager.users.cloudburst = {
      xdg.configFile."mimeapps.list".force = true;
      xdg.mimeApps.enable = true;
    };
  };
}
