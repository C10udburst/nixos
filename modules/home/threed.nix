{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.homeSettings.threed;
  blenderVersion = lib.versions.majorMinor pkgs.blender.version;
in {
  options.homeSettings.threed = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable 3D home-manager configuration (OpenSCAD libraries, Blender Stylix theme etc.)";
  };

  config = {
    stylix.targets.blender.enable = cfg;

    xdg.configFile = lib.mkIf cfg {
      "blender/${blenderVersion}/scripts/presets/interface_theme/Stylix.xml".source =
        config.xdg.configFile."blender/4.5/scripts/presets/interface_theme/Stylix.xml".source;
    };

    xdg.dataFile = lib.mkIf cfg {
      "OpenSCAD/libraries/BOSL2".source = inputs.openscad-bosl2;
      "OpenSCAD/libraries/constructive".source = inputs.openscad-constructive;
      "OpenSCAD/libraries/Round-Anything".source = inputs.openscad-round-anything;
      "OpenSCAD/libraries/obiscad".source = inputs.openscad-obiscad;
    };
  };
}
