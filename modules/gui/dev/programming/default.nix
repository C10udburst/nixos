{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.dev.programming;
in {
  options.features.gui.dev.programming = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = (config.features.gui.enable && config.features.gui.dev.enable) && true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gcc
    ];

    boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  };
}
