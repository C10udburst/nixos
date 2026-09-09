{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.apps.threed.enable;
  cfg = config.features.gui.apps.threed.blender;
  blenderVersion = lib.versions.majorMinor pkgs.blender.version;
in {
  options.features.gui.apps.threed.blender = lib.mkOption {
    type = lib.types.bool;
    default = threedEnabled && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [pkgs.blender];

    home-manager.users.cloudburst = lib.mkMerge [
      (lib.mkIf (config.stylix.enable or false) {
        stylix.targets.blender.enable = true;

        xdg.configFile = {
          "blender/${blenderVersion}/scripts/presets/interface_theme/Stylix.xml".source =
            config.home-manager.users.cloudburst.xdg.configFile."blender/4.5/scripts/presets/interface_theme/Stylix.xml".source;
        };
      })
    ];
  };
}
