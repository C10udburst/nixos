{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.obs;
in {
  options.systemSettings.obs = {
    enable = lib.mkEnableOption "Enable OBS Studio with plugins";
  };

  config = lib.mkIf cfg.enable {
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
