{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.gui.apps.brave;
  isSlow = config.features.core.hardware.slow or false;
in {
  options.features.gui.apps.brave = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if (config.features.gui.enable && config.features.gui.apps.enable)
        then true
        else false;
    };
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    extraCliFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        webicons = {
          url = "github:C10udburst/webicons-nix";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf (config.features.gui.enable && config.features.gui.apps.enable && cfg.enable) {
      environment.etc."brave/policies/managed/GroupPolicy.json".text = builtins.toJSON (
        {
          PasswordManagerEnabled = false;
          SpellcheckEnabled = true;
          SpellcheckLanguage = [
            "pl-PL"
            "en-US"
          ];
          BraveRewardsDisabled = true;
          BraveWalletDisabled = true;
          BraveVPNDisabled = true;
          BraveAIChatEnabled = false;
          BraveNewsDisabled = true;
          BraveTalkDisabled = true;
          BraveSpeedreaderEnabled = true;
          BraveP3AEnabled = false;
          BraveStatsPingEnabled = false;
          BraveWebDiscoveryEnabled = false;
          PasswordSharingEnabled = false;
          PasswordLeakDetectionEnabled = false;
          ExtensionManifestV2Availability = 2;
          SafeBrowsingExtendedReportingEnabled = false;
          SafeBrowsingSurveysEnabled = false;
          SafeBrowsingDeepScanningEnabled = false;
          AlternateErrorPagesEnabled = false;
          FeedbackSurveysEnabled = false;
          BrowserGuestModeEnabled = true;
        }
        // lib.optionalAttrs isSlow {
          HighEfficiencyModeEnabled = true;
          MemorySaverModeSavings = "MAXIMUM";
        }
      );

      environment.systemPackages = [
        (pkgs.brave.override {
          commandLineArgs =
            [
              "--allow-insecure-localhost"
              "--ozone-platform=wayland"
              "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,VaapiVideoDecodeLinuxGL,Vulkan,VulkanFromANGLE,DefaultANGLEVulkan"
              "--use-angle=gl"
              "--user-gl=angle"
              "--use-vulkan"
              "--ignore-gpu-blocklist"
              "--force-device-scale-factor=0.9"
              "--password-store=basic"
            ]
            ++ lib.optionals isSlow [
              "--enable-low-end-device-mode"
            ]
            ++ cfg.extraCliFlags;
        })
      ];

      home-manager.users.cloudburst = {
        xdg.mimeApps.defaultApplications = {
          "text/html" = "brave-browser.desktop";
          "x-scheme-handler/http" = "brave-browser.desktop";
          "x-scheme-handler/https" = "brave-browser.desktop";
        };
      };
    })
  ];
}
