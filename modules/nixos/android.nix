{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.android;
in {
  options.systemSettings.android = {
    enable = lib.mkEnableOption "Enable Android tools and settings";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      scrcpy
      android-tools
      jmtpfs
      android-file-transfer
    ];
  };
}
