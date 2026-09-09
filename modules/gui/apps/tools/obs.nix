{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.apps.tools.obs;
  toolsEnabled = config.features.gui.apps.tools.enable;
in {
  options.features.gui.apps.tools.obs = lib.mkOption {
    type = lib.types.bool;
    default = toolsEnabled && true;
  };

  config = lib.mkIf cfg {
    programs.obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        obs-backgroundremoval
        wlrobs
      ];
    };
  };
}
