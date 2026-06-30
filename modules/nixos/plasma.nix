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

    environment.systemPackages = with pkgs; [
      kdePackages.plasma-systemmonitor
      kdePackages.kwalletmanager
      kdePackages.kmix
      kdePackages.ksystemlog
    ];
  };
}
