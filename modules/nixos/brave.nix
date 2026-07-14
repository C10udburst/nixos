{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.brave;
in {
  options.systemSettings.brave = {
    enable = lib.mkEnableOption "Enable brave group policies";
    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "brave-history-embeddings@1"
        "brave-origin@1"
        "brave-tree-tab@1"
        "containers@1"
        "enable-parallel-downloading@1"
        "enable-quic@1"
        "middle-button-autoscroll@1"
        "smooth-scrolling@1"
      ];
      description = "List of Brave flags (experiments) to enable declaratively";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."brave/policies/managed/GroupPolicy.json".text = ''
      {
        "PasswordManagerEnabled": false,
        "SpellcheckEnabled": true,
        "SpellcheckLanguage": [
          "pl-PL",
          "en-US"
        ],
        "BraveRewardsDisabled": true,fun flags?
        "BraveWalletDisabled": true,
        "BraveVPNDisabled": true,
        "BraveAIChatEnabled": false,
        "BraveNewsDisabled": true,
        "BraveTalkDisabled": true,
        "BraveSpeedreaderEnabled": true,
        "BraveP3AEnabled": false,
        "BraveStatsPingEnabled": false,
        "BraveWebDiscoveryEnabled": false,
        "PasswordSharingEnabled": false,
        "PasswordLeakDetectionEnabled": false,
        "ExtensionManifestV2Availability": 2,
        "SafeBrowsingExtendedReportingEnabled": false,
        "SafeBrowsingSurveysEnabled": false,
        "SafeBrowsingDeepScanningEnabled": false,
        "AlternateErrorPagesEnabled": false,
        "FeedbackSurveysEnabled": false,
        "BrowserGuestModeEnabled": true
      }
    '';
    environment.systemPackages = with pkgs; [
      (brave.override {
        commandLineArgs = [
          "--allow-insecure-localhost"
          "--ozone-platform=x11"
          "--enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan"
          "--use-angle=vulkan"
          "--use-vulkan"
          "--ignore-gpu-blocklist"
          "--force-device-scale-factor=0.9"
          "--password-store=basic"
        ];
      })
    ];

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
          --argjson flags '${builtins.toJSON cfg.flags}' \
          "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
      '';
    };
  };
}
