{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.programming;
in {
  options.systemSettings.programming = {
    enable = lib.mkEnableOption "Enable programming languages (Rust, Go, and Node.js)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rustc
      cargo
      go
      nodejs
      pnpm
      sqlitebrowser
      kotlin
      imhex
      gdb
      gcc
      qgit
    ];

    boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  };
}
