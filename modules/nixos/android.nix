{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.android;

  scrcpy-app = let
    pythonApp = pkgs.writers.writePython3Bin "scrcpy-app" {
      libraries = with pkgs.python3Packages; [pyqt6];
    } (builtins.readFile ./scrcpy-app.py);
  in
    pkgs.symlinkJoin {
      name = "scrcpy-app";
      paths = [
        (pkgs.runCommand "scrcpy-app-wrapped" {
            nativeBuildInputs = [pkgs.makeWrapper];
          } ''
            mkdir -p $out/bin
            makeWrapper ${pythonApp}/bin/scrcpy-app $out/bin/scrcpy-app \
              --prefix PATH : ${lib.makeBinPath [pkgs.aapt pkgs.android-tools pkgs.scrcpy]}
          '')
        (pkgs.makeDesktopItem {
          name = "scrcpy-app";
          exec = "scrcpy-app";
          icon = "phone";
          comment = "Run Android app on PC via scrcpy";
          desktopName = "Scrcpy App";
          categories = ["Utility"];
        })
      ];
    };
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
