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
      default = config.features.gui.enable && true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libnotify
      zenity
    ];
  };
}
