{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.gui.apps.viewers.okular;
  viewersEnabled = config.features.gui.apps.viewers.enable;
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
  ) (helpers.associatePackage pkgs.kdePackages.okular);
in {
  options.features.gui.apps.viewers.okular = lib.mkOption {
    type = lib.types.bool;
    default = viewersEnabled && true;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.kdePackages.okular];
      xdg.mimeApps.defaultApplications = okularMimes;
    };
  };
}
