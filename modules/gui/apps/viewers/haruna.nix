{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.viewers.haruna;
  viewersEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.viewers.enable;
  associatePackage = (import ../../../../lib/helpers/associations.nix {inherit lib;}).associatePackage;
  harunaMimes = lib.filterAttrs (
    name: _: lib.hasPrefix "video/" name || lib.hasPrefix "audio/" name
  ) (associatePackage pkgs.haruna);
in {
  options.features.gui.apps.viewers.haruna = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (viewersEnabled && cfg) {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.haruna];
      xdg.mimeApps.defaultApplications = harunaMimes;
    };
  };
}
