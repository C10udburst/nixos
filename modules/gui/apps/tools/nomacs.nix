{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.nomacs;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable;
  associatePackage = (import ../../../../lib/helpers/associations.nix {inherit lib;}).associatePackage;
  nomacsMimes = lib.filterAttrs (name: _: lib.hasPrefix "image/" name) (associatePackage pkgs.nomacs);
in {
  options.features.gui.apps.tools.nomacs = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (toolsEnabled && cfg) {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.nomacs];
      xdg.mimeApps.defaultApplications = nomacsMimes;
    };
  };
}
