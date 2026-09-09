{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.nix;
in {
  options.features.shell.utils.nix = lib.mkOption {
    type = lib.types.bool;
    default = config.features.shell.utils.enable && true;
  };

  config = lib.mkMerge [
    {
      programs.command-not-found.enable = lib.mkIf config.programs.nix-index.enable (lib.mkDefault false);
    }
    (lib.mkIf cfg {
      programs.nix-index = {
        enable = true;
        enableBashIntegration = true;
      };

      environment.systemPackages = with pkgs; [
        alejandra
        nix-output-monitor
        nix-heuristic-gc
      ];
    })
  ];
}
