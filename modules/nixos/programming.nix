{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.programming;
in {
  options.systemSettings.programming = {
    enable = lib.mkEnableOption "Enable programming toolchain (shared tools + per-language flags)";

    rust = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Rust (rustc + cargo)";
    };

    go = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Go";
    };

    node = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Node.js + pnpm";
    };

    kotlin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Kotlin";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [
        # Shared dev tools
        sqlitebrowser
        imhex
        gdb
        gcc
        qgit
      ]
      ++ lib.optionals cfg.rust [rustc cargo]
      ++ lib.optionals cfg.go [go]
      ++ lib.optionals cfg.node [nodejs pnpm]
      ++ lib.optionals cfg.kotlin [kotlin];

    boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  };
}
