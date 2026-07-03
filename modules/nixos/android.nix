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

    environment.sessionVariables = {
      ANDROID_HOME = "/run/current-system/sw/libexec/android-sdk";
      ANDROID_SDK_ROOT = "/run/current-system/sw/libexec/android-sdk";
    };

    environment.systemPackages = with pkgs; [
      scrcpy
      android-tools
      jmtpfs
      android-file-transfer
      jadx
      (androidenv.composeAndroidPackages {
        platformVersions = ["35"];
      }).androidsdk
    ];
  };
}
