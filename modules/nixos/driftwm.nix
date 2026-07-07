{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.driftwm;
in {
  options.systemSettings.driftwm = {
    enable = lib.mkEnableOption "Enable driftwm system-level configuration";
  };

  config = lib.mkIf cfg.enable {
    # Expose systemd units from driftwm package
    systemd.packages = [
      pkgs.driftwm
      pkgs.xwayland-satellite
    ];

    security.pam.services.swaylock = lib.mkDefault {};
    services.graphical-desktop.enable = lib.mkDefault true;
    security.polkit.enable = lib.mkDefault true;
    services.displayManager.sessionPackages = [pkgs.driftwm];

    services.gnome.gnome-keyring.enable = lib.mkDefault true;

    # Fix empty "Open With" / default apps in Dolphin and Konsole when running
    # outside of a full Plasma session. KDE service discovery (kbuildsycoca6)
    # looks for the applications menu under the XDG_MENU_PREFIX name; outside
    # Plasma this prefix is not set, so we provide the symlink directly.
    environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

    # Set XDG_MENU_PREFIX so KDE apps inside DriftWM find the Plasma app menu
    environment.sessionVariables.XDG_MENU_PREFIX = "plasma-";

    systemd.user.services.driftwm = {
      restartIfChanged = false;
      enableDefaultPath = false;
    };

    xdg.portal = {
      enable = lib.mkDefault true;
      configPackages = lib.mkDefault [pkgs.driftwm];
      extraPortals = lib.mkDefault [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
      ];
    };
  };
}
