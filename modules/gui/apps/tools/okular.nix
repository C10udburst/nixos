{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.okular;
  toolsEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.tools.enable;
  associatePackage = (import ../../../../lib/helpers/associations.nix {inherit lib;}).associatePackage;
  okularMimes = lib.filterAttrs (
    name: value:
      !(builtins.any (
          desktopFile:
            lib.hasSuffix "tiff.desktop" desktopFile
            || lib.hasSuffix "txt.desktop" desktopFile
            || lib.hasSuffix "md.desktop" desktopFile
        )
        value)
      && name != "image/tiff"
  ) (associatePackage pkgs.kdePackages.okular);
in {
  options.features.gui.apps.tools.okular = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf (toolsEnabled && cfg) {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.kdePackages.okular];
      xdg.mimeApps.defaultApplications = okularMimes;
    };
  };
}
