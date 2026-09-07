{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.haruna;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable;
  associatePackage = (import ../../../../lib/helpers/associations.nix {inherit lib;}).associatePackage;
  harunaMimes = lib.filterAttrs (
    name: _: lib.hasPrefix "video/" name || lib.hasPrefix "audio/" name
  ) (associatePackage pkgs.haruna);
in {
  options.features.gui.apps.tools.haruna = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (toolsEnabled && cfg) {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.haruna];
      xdg.mimeApps.defaultApplications = harunaMimes;
    };
  };
}
