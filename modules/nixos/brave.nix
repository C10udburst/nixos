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
        "DefaultSearchProviderAlternateURLS": [
          "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"
        ],
        "PasswordSharingEnabled": false,
        "PasswordLeakDetectionEnabled": false,
        "ReportAppInventory": [""],
        "ExtensionManifestV2Availability": 2,
        "SafeBrowsingExtendedReportingEnabled": false,
        "SafeBrowsingSurveysEnabled": false,
        "SafeBrowsingDeepScanningEnabled": false,
        "DeviceActivityHeartbeatEnabled": false,
        "DeviceMetricsReportingEnabled": false,
        "HeartbeatEnabled": false,
        "LogUploadEnabled": false,
        "ReportAppInventory": [""],
        "ReportDeviceActivityTimes": false,
        "ReportDeviceAppInfo": false,
        "ReportDeviceSystemInfo": false,
        "ReportDeviceUsers": false,
        "ReportWebsiteTelemetry": [""],
        "AlternateErrorPagesEnabled": false,
        "FeedbackSurveysEnabled": false,
        "BrowserGuestModeEnabled": true
      }
    '';
    environment.systemPackages = with pkgs; [
      brave
    ];
  };
}
