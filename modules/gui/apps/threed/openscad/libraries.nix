{
  config,
  lib,
  inputs,
  ...
}: let
  threedEnabled = config.features.gui.enable && config.features.gui.apps.threed.enable;
  openscadEnabled = threedEnabled && config.features.gui.apps.threed.openscad.enable;
  cfg = config.features.gui.apps.threed.openscad.libraries;
in {
  options.features.gui.apps.threed.openscad.libraries = lib.mkOption {
    type = lib.types.bool;
    default = openscadEnabled && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        openscad-bosl2 = {
          url = "github:BelfrySCAD/BOSL2";
          flake = false;
        };
        openscad-constructive = {
          url = "git+https://codeberg.org/solidboredom/constructive";
          flake = false;
        };
        openscad-round-anything = {
          url = "github:Irev-Dev/Round-Anything";
          flake = false;
        };
        openscad-obiscad = {
          url = "github:Obijuan/obiscad?dir=obiscad";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg {
      home-manager.users.cloudburst = {
        xdg.dataFile = {
          "OpenSCAD/libraries/BOSL2".source = inputs.openscad-bosl2;
          "OpenSCAD/libraries/constructive".source = inputs.openscad-constructive;
          "OpenSCAD/libraries/Round-Anything".source = inputs.openscad-round-anything;
          "OpenSCAD/libraries/obiscad".source = inputs.openscad-obiscad;
        };
      };
    })
  ];
}
