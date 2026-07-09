{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.plasma;
in {
  options.systemSettings.plasma = {
    enable = lib.mkEnableOption "Enable KDE Plasma desktop environment";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "pl";
      variant = "";
    };

    # Configure console keymap
    console.keyMap = "pl2";

    # Enable Xwayland
    programs.xwayland.enable = true;
    programs.kdeconnect.enable = true;

    # Mouse acceleration - flat/none profile (often preferred for Windows-like feel)
    services.libinput.mouse.accelProfile = "flat";
    services.libinput.mouse.accelSpeed = "0";

    environment.systemPackages = with pkgs; [
      kdePackages.plasma-systemmonitor
      kdePackages.kwalletmanager
      kdePackages.ksystemlog
      kdePackages.kdeconnect-kde
      kdePackages.kde-cli-tools
    ];

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      discover
      plasma-browser-integration
      khelpcenter
    ];
  };
}
