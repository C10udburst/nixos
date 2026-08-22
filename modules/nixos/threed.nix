{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.threed;
in {
  options.systemSettings.threed = {
    enable = lib.mkEnableOption "Enable 3D modeling and slicing tools (Blender, OrcaSlicer, OpenSCAD, FreeCAD)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      blender
      orca-slicer
      openscad
      freecad
    ];
  };
}
