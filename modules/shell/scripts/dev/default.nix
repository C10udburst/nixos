{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.scripts.dev;
  gh-origin-mod = pkgs.writeShellScriptBin "gh-origin-mod" (builtins.readFile ./_gh-origin-mod.sh);
  nix-py = pkgs.writeShellScriptBin "nix-py" (builtins.readFile ./_nix-py.sh);
  nx = pkgs.writeShellScriptBin "nx" (builtins.readFile ./_nx.sh);
  sarif-md = pkgs.writers.writePython3Bin "sarif-md" {} (builtins.readFile ./_sarif-md.py);
in {
  options.features.shell.scripts.dev = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.scripts.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.scripts.enable && cfg) {
    environment.systemPackages = [
      gh-origin-mod
      nix-py
      nx
      sarif-md
    ];
  };
}
