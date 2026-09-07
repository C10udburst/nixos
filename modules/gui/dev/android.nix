{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  devEnabled = config.features.gui.enable && config.features.gui.dev.enable;
  cfg = config.features.gui.dev.android;
  scrcpy-app = inputs.scrcpy-app-src.defaultPackage.${pkgs.system} or null;
in {
  options.features.gui.dev.android = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    core = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    scrcpy = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    dev = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        scrcpy-app-src = {
          url = "github:C10udburst/scrcpy-app";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf (devEnabled && cfg.enable) {
      nixpkgs.config.android_sdk.accept_license = true;

      environment.sessionVariables = lib.mkIf cfg.dev {
        ANDROID_HOME = "/run/current-system/sw/libexec/android-sdk";
        ANDROID_SDK_ROOT = "/run/current-system/sw/libexec/android-sdk";
      };

      environment.systemPackages =
        lib.optionals cfg.core (
          with pkgs; [
            android-tools
            jmtpfs
            android-file-transfer
          ]
        )
        ++ lib.optionals cfg.scrcpy (
          with pkgs;
            [
              scrcpy
            ]
            ++ lib.optional (scrcpy-app != null) scrcpy-app
        )
        ++ lib.optionals cfg.dev [
          pkgs.jadx
          (pkgs.androidenv.composeAndroidPackages {
            platformVersions = ["35" "36"];
            buildToolsVersions = ["35.0.0"];
          }).androidsdk
        ];
    })
  ];
}
