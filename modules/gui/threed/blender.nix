{
  config,
  lib,
  pkgs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.threed.enable;
  cfg = config.features.gui.threed.blender;
  blenderVersion = lib.versions.majorMinor pkgs.blender.version;
in {
  options.features.gui.threed.blender = lib.mkOption {
    type = lib.types.bool;
    default =
      if threedEnabled
      then true
      else false;
  };

  config = lib.mkIf (threedEnabled && cfg) {
    environment.systemPackages = [pkgs.blender];

    home-manager.users.cloudburst = {
      stylix.targets.blender.enable = true;

      xdg.configFile = {
        "blender/${blenderVersion}/scripts/presets/interface_theme/Stylix.xml".source =
          config.home-manager.users.cloudburst.xdg.configFile."blender/4.5/scripts/presets/interface_theme/Stylix.xml".source;
      };
    };
  };
}
