{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.appimage;
in {
  options.systemSettings.appimage = {
    enable = lib.mkEnableOption "Enable AppImage support (appimage-run)";
  };

  config = lib.mkIf cfg.enable {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
