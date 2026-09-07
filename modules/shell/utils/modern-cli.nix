{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.shell.utils.modernCli;
in {
  options.features.shell.utils.modernCli = lib.mkOption {
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
      asciinema
      qrencode
      zbar
      jq
      tmux
      curl
      wget
      file
      alejandra
      nix-output-monitor
      nix-heuristic-gc
      libnotify
    ];
  };
}
