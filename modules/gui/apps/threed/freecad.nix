{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  threedEnabled = config.features.gui.apps.threed.enable;
  cfg = config.features.gui.apps.threed.freecad;
  # Upstream bug (APEbbers/SearchBar#47, PR#48 unmerged): the except-handler in
  # getAllToolbars calls workbench.name() on unloaded workbenches, which raises
  # AttributeError and kills the whole toolbar cache refresh. Use the loop's
  # wbname instead. Drop when a released tag containing the fix is locked.
  searchbar = pkgs.runCommand "freecad-searchbar" {} ''
    cp -r --no-preserve=mode ${inputs.freecad-searchbar} $out
    substituteInPlace $out/ResultsToolbar.py \
      --replace-fail 'print(f"{workbench.name()} not available")' 'print(f"{wbname} not available")'
  '';
  # Upstream breakage on CurvesWB main (2587899): init_gui.py imports
  # RectangularFaceFP and lists a Curves_RectangularFace command, but that module
  # exists on no branch or tag, so the ImportError aborts the whole
  # CurvesWorkbench registration. Drop both. Revert once upstream ships the file.
  curveswb = pkgs.runCommand "freecad-curveswb" {} ''
    cp -r --no-preserve=mode ${inputs.curveswb} $out
    sed -i '/from \. import RectangularFaceFP/d' $out/freecad/Curves/init_gui.py
    substituteInPlace $out/freecad/Curves/init_gui.py \
      --replace-fail ' "Curves_RectangularFace"]' ']'
  '';
in {
  options.features.gui.apps.threed.freecad = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = threedEnabled && true;
    };
    modules = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        simplecad = {
          url = "github:igsova/SimpleCAD";
          flake = false;
        };
        freecad-nxt = {
          url = "github:obelisk79/FreeCAD-Nxt";
          flake = false;
        };
        freecad-searchbar = {
          url = "github:APEbbers/SearchBar";
          flake = false;
        };
        pimpmyfreecad = {
          url = "github:sedatkrn/PimpMyFreeCAD";
          flake = false;
        };
        curveswb = {
          url = "github:tomate44/CurvesWB";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        (
          if cfg.modules
          then
            pkgs.freecad.customize {
              name = "freecad-with-modules";
              modules = [
                inputs.simplecad
                inputs.freecad-nxt
                searchbar
                # Rail Pipe / Rail Groove, Magic Loft and Dome for PartDesign and
                # Part. Plain addon tree (Init.py + InitGui.py), no third-party
                # Python beyond the numpy/pivy FreeCAD already ships.
                inputs.pimpmyfreecad
                # Curves workbench: NURBS curves and surfaces (parametric blend
                # curve, Gordon surfaces, sweep on rails, discretize, geometric
                # analysis). Namespace addon (package.xml + freecad/Curves with
                # init_gui.py), discovered by pkgutil on the module path; its
                # declared deps are numpy/scipy, both already bundled by FreeCAD.
                curveswb
              ];
              # SearchBar needs defusedxml (startup XML parsing, dark-mode
              # detection) and lxml (search results); Curves only needs
              # defusedxml for Paste SVG and falls back to xml.sax; Nxt,
              # SimpleCAD and Pimp My FreeCAD use what FreeCAD already bundles.
              pythons = [
                (ps: [ps.defusedxml ps.lxml])
              ];
            }
          else pkgs.freecad
        )
      ];
    })
  ];
}
