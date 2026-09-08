{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.viewers.haruna;
  viewersEnabled =
    config.features.gui.enable && config.features.gui.apps.enable && config.features.gui.apps.viewers.enable;
  inherit ((import ../../../../lib/helpers/associations.nix {inherit lib;})) associatePackage;
  harunaMimes = lib.filterAttrs (
    name: _: lib.hasPrefix "video/" name || lib.hasPrefix "audio/" name
  ) (associatePackage pkgs.haruna);
in {
  options.features.gui.apps.viewers.haruna = lib.mkOption {
    type = lib.types.bool;
    default = viewersEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.haruna];

    home-manager.users.cloudburst = {
      xdg.mimeApps.defaultApplications = harunaMimes;
    };
  };
}
