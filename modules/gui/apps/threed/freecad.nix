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
              ];
              # SearchBar needs defusedxml (startup XML parsing, dark-mode
              # detection) and lxml (search results); Nxt and SimpleCAD use only
              # what FreeCAD already bundles.
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
