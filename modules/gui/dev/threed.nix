{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  devEnabled = config.features.gui.enable && config.features.gui.dev.enable;
  cfg = config.features.gui.dev.threed;
  blenderVersion = lib.versions.majorMinor pkgs.blender.version;
in {
  options.features.gui.dev.threed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    blender = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    orca = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    freecad = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    openscad = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      libraries = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf (devEnabled && cfg.enable) {
    environment.systemPackages =
      lib.optional cfg.blender pkgs.blender
      ++ lib.optional cfg.orca pkgs.orca-slicer
      ++ lib.optional cfg.freecad pkgs.freecad
      ++ lib.optional cfg.openscad.enable pkgs.openscad;

    home-manager.users.cloudburst = {
      stylix.targets.blender.enable = lib.mkIf cfg.blender true;

      xdg.configFile = lib.mkIf cfg.blender {
        "blender/${blenderVersion}/scripts/presets/interface_theme/Stylix.xml".source =
          config.home-manager.users.cloudburst.xdg.configFile."blender/4.5/scripts/presets/interface_theme/Stylix.xml".source;
      };

      xdg.dataFile = lib.mkIf (cfg.openscad.enable && cfg.openscad.libraries) {
        "OpenSCAD/libraries/BOSL2".source = inputs.openscad-bosl2;
        "OpenSCAD/libraries/constructive".source = inputs.openscad-constructive;
        "OpenSCAD/libraries/Round-Anything".source = inputs.openscad-round-anything;
        "OpenSCAD/libraries/obiscad".source = inputs.openscad-obiscad;
      };
    };
  };
}
