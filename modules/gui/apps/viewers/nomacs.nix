{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.gui.apps.viewers.nomacs;
  viewersEnabled = config.features.gui.apps.viewers.enable;
  svgMimes = {
    "image/svg+xml" = ["org.nomacs.ImageLounge.desktop"];
    "image/svg+xml-compressed" = ["org.nomacs.ImageLounge.desktop"];
  };
  nomacsMimes =
    (lib.filterAttrs (name: _: lib.hasPrefix "image/" name) (helpers.associatePackage pkgs.nomacs))
    // svgMimes;
in {
  options.features.gui.apps.viewers.nomacs = lib.mkOption {
    type = lib.types.bool;
    default = viewersEnabled && true;
  };

  config = lib.mkIf cfg {
    home-manager.users.cloudburst = {
      home.packages = [pkgs.nomacs];
      xdg.mimeApps = {
        defaultApplications = nomacsMimes;
        associations.added = svgMimes;
      };
    };
  };
}
