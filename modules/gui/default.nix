{
  config,
  lib,
  ...
}: {
  options.features.gui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf config.features.gui.enable {
    home-manager.users.cloudburst = {
      xdg.configFile."mimeapps.list".force = true;
      xdg.mimeApps.enable = true;
    };
  };
}
