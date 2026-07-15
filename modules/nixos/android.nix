{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.android;
  scrcpy-app = inputs.scrcpy-app-src.defaultPackage.${pkgs.system};
in {
  options.systemSettings.android = {
    enable = lib.mkEnableOption "Enable Android tools and settings";
    dev = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Android development tools (SDK and jadx)";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.android_sdk.accept_license = true;

    environment.sessionVariables = lib.mkIf cfg.dev {
      ANDROID_HOME = "/run/current-system/sw/libexec/android-sdk";
      ANDROID_SDK_ROOT = "/run/current-system/sw/libexec/android-sdk";
    };

    environment.systemPackages = with pkgs;
      [
        scrcpy
        android-tools
        jmtpfs
        android-file-transfer
        scrcpy-app
      ]
      ++ lib.optionals cfg.dev [
        jadx
        (androidenv.composeAndroidPackages {
          platformVersions = ["35"];
        }).androidsdk
      ];
  };
}
