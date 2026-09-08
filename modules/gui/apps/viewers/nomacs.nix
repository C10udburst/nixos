{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.viewers.nomacs;
  viewersEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.viewers.enable;
  inherit ((import ../../../../lib/helpers/associations.nix {inherit lib;})) associatePackage;
  nomacsMimes = lib.filterAttrs (name: _: lib.hasPrefix "image/" name) (associatePackage pkgs.nomacs);
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
