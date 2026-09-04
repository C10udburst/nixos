{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.brave;
  isSlow = config.hostSettings.slow or false;
  effectiveFlags = cfg.flags;

  icons = inputs.webicons.packages.${pkgs.system};
  apps = import ./apps.nix {inherit config lib pkgs icons;};
in {
  options.systemSettings.brave = {
    enable = lib.mkEnableOption "Enable brave group policies and webapps";
    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "brave-dark-mode-block@2"
        "brave-history-embeddings@1"
        "brave-origin@1"
        "brave-tree-tab@1"
        "containers@1"
        "enable-parallel-downloading@1"
        "enable-quic@1"
        "middle-button-autoscroll@1"
        "smooth-scrolling@1"
        "ignore-gpu-blocklist@1"
        "brave-round-time-stamps@1"
        "brave-web-bluetooth-api@1"
        "brave-rounded-corners-by-default@1"
        "brave-request-otr-tab@1"
      ];
      description = "List of Brave flags (experiments) to enable declaratively";
    };
    webapps = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [];
      description = "List of webapps to create desktop items for (can be URLs or webApp attrsets)";
    };
  };

  config = lib.mkIf cfg.enable {
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

    environment.systemPackages =
      [
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
            ];
        })
      ]
      ++ apps.allDesktopItems;

    systemd.user.services.brave-flags = {
      description = "Set Brave flags declaratively";
      wantedBy = ["default.target"];
      script = ''
        STATE_FILE="$HOME/.config/BraveSoftware/Brave-Browser/Local State"
        mkdir -p "$(dirname "$STATE_FILE")"
        if [ ! -f "$STATE_FILE" ]; then
          echo "{}" > "$STATE_FILE"
        fi
        ${pkgs.jq}/bin/jq '.browser.enabled_labs_experiments = $flags' \
          --argjson flags '${builtins.toJSON effectiveFlags}' \
          "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
      '';
    };
  };
}
