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
        "BraveRewardsDisabled": true,
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
        "BrowserGuestModeEnabled": true,
      }
    '';
    environment.systemPackages = with pkgs; [
      (brave.override {
        commandLineArgs = [
          "--allow-insecure-localhost"
          "--ozone-platform-hint=wayland"
          "--enable-features=Vulkan,WaylandWindowDecorations"
          "--enable-unsafe-webgpu"
          "--ignore-gpu-blocklist"
          "--force-device-scale-factor=0.9"
          "--password-store=basic"
        ];
      })
    ];
  };
}
