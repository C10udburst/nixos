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
    default =
      if (config.features.shell.enable && config.features.shell.utils.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.utils.enable && cfg) {
    environment.systemPackages = with pkgs; [
      alejandra
      nix-output-monitor
      nix-heuristic-gc
      nix-index
    ];
  };
}
