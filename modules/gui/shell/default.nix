{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.shell;
in {
  options.features.gui.shell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.gui.enable
        then true
        else false;
    };
  };

  config = lib.mkIf (config.features.gui.enable && cfg.enable) {
    environment.systemPackages = with pkgs; [
      libnotify
      zenity
    ];
  };
}
