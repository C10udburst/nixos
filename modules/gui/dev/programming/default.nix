{
  config,
  lib,
  pkgs,
  ...
}: let
  devEnabled = config.features.gui.enable && config.features.gui.dev.enable;
  cfg = config.features.gui.dev.programming;
in {
  options.features.gui.dev.programming = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if (config.features.gui.enable && config.features.gui.dev.enable)
        then true
        else false;
    };
  };

  config = lib.mkIf (devEnabled && cfg.enable) {
    environment.systemPackages = with pkgs; [
      gcc
    ];

    boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;
  };
}
