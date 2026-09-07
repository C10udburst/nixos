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
    default = (config.features.shell.enable && config.features.shell.utils.enable) && true;
  };

  config = lib.mkIf cfg {
    environment.systemPackages = with pkgs; [
      alejandra
      nix-output-monitor
      nix-heuristic-gc
      nix-index
    ];
  };
}
