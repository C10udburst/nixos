{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.modern;
in {
  options.features.shell.utils.modern = lib.mkOption {
    type = lib.types.bool;
    default =
      if (config.features.shell.enable && config.features.shell.utils.enable)
      then true
      else false;
  };

  config = lib.mkIf (config.features.shell.enable && config.features.shell.utils.enable && cfg) {
    environment.systemPackages = with pkgs; [
      bat
      eza
      fd
      ripgrep
      procs
      dust
      fzf
      hexyl
      binwalk
      tmux
      jless
    ];
  };
}
