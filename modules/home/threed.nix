{
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.homeSettings.threed;
in {
  options.homeSettings.threed = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable 3D home-manager configuration (OpenSCAD libraries etc.)";
  };

  config = lib.mkIf cfg {
    # Install OpenSCAD libraries declaratively by symlinking their source
    # from flake inputs into the standard OpenSCAD user library path.
    # OpenSCAD resolves `use <LibName/file.scad>` from each entry in
    # `$OPENSCADPATH` and from `~/.local/share/OpenSCAD/libraries/`.
    xdg.dataFile = {
      "OpenSCAD/libraries/BOSL2".source = inputs.openscad-bosl2;
      "OpenSCAD/libraries/constructive".source = inputs.openscad-constructive;
      "OpenSCAD/libraries/Round-Anything".source = inputs.openscad-round-anything;
    };
  };
}
