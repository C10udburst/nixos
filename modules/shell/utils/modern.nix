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
    default = config.features.shell.utils.enable && true;
  };

  config = lib.mkIf cfg {
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
