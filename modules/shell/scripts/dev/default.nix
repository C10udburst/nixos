{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.shell.scripts.dev;
  gh-origin-mod = pkgs.writeShellScriptBin "gh-origin-mod" (builtins.readFile ./_gh-origin-mod.sh);
  nix-py = pkgs.writeShellScriptBin "nix-py" (builtins.readFile ./_nix-py.sh);
  nx = pkgs.writeShellScriptBin "nx" (builtins.readFile ./_nx.sh);
  sarif-md = pkgs.writers.writePython3Bin "sarif-md" {} (builtins.readFile ./_sarif-md.py);
  oci-lock = inputs.oci-lock.packages.${pkgs.system}.default;
in {
  options.features.shell.scripts.dev = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.scripts.enable && true;
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        oci-lock = {
          url = "github:C10udburst/oci-lock";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg {
      environment.systemPackages = [
        gh-origin-mod
        nix-py
        nx
        sarif-md
        oci-lock
      ];
    })
  ];
}
