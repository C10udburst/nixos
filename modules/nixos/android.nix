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
    nixpkgs.config.android_sdk.accept_license = true;

    environment.systemPackages = with pkgs; [
      scrcpy
      android-tools
      jmtpfs
      android-file-transfer
      androidenv.androidPkgs.androidsdk
    ];
  };
}
