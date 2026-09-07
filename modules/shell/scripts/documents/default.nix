{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.scripts.documents;
  beamer-clean = pkgs.writers.writePython3Bin "beamer-clean" {libraries = with pkgs.python3Packages; [pypdf];} (builtins.readFile ./_beamer-clean.py);
  ics-merge = pkgs.writers.writePython3Bin "ics-merge" {} (builtins.readFile ./_ics-merge.py);
  gcode-bounds = pkgs.writers.writePython3Bin "gcode-bounds" {} (builtins.readFile ./_gcode-bounds.py);
in {
  options.features.shell.scripts.documents = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.scripts.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.scripts.enable && cfg) {
    environment.systemPackages = [
      beamer-clean
      ics-merge
      gcode-bounds
    ];
  };
}
