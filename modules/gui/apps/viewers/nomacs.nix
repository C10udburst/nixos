{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.gui.apps.viewers.nomacs;
  viewersEnabled = config.features.gui.apps.viewers.enable;
  nomacsMimes = lib.filterAttrs (name: _: lib.hasPrefix "image/" name) (helpers.associatePackage pkgs.nomacs);
in {
  options.features.gui.apps.viewers.nomacs = lib.mkOption {
    type = lib.types.bool;
    default = viewersEnabled && true;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.nomacs];
      xdg.mimeApps.defaultApplications = nomacsMimes;
    };
  };
}
