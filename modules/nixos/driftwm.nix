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
    ];
    environment.systemPackages = [
      pkgs.driftwm
      pkgs.wlr-randr
      pkgs.playerctl
      pkgs.pavucontrol
      pkgs.pamixer
      pkgs.kdePackages.dolphin
      pkgs.xwayland-satellite

      # Qt / SVG icon support
      pkgs.libsForQt5.qtsvg
      pkgs.kdePackages.qtsvg
      pkgs.libsForQt5.qt5ct
      pkgs.kdePackages.qt6ct
    ];

    security.pam.services.swaylock = lib.mkDefault {};
    services.graphical-desktop.enable = lib.mkDefault true;
    security.polkit.enable = lib.mkDefault true;

    services.gnome.gnome-keyring.enable = lib.mkDefault true;

    # Fix empty "Open With" / default apps in Dolphin and Konsole when running
    # outside of a full Plasma session. KDE service discovery (kbuildsycoca6)
    # looks for the applications menu under the XDG_MENU_PREFIX name; outside
    # Plasma this prefix is not set, so we provide the symlink directly.
    environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

    # Set XDG_MENU_PREFIX so KDE apps inside DriftWM find the Plasma app menu
    environment.sessionVariables.XDG_MENU_PREFIX = "plasma-";

    # Tell the XDG portal dispatcher which desktop we are so it can pick
    # the right portal backend (wlr for ScreenCast / Screenshot).
    environment.sessionVariables.XDG_CURRENT_DESKTOP = "sway";

    systemd.user.services.driftwm = {
      restartIfChanged = false;
      enableDefaultPath = false;
    };

    services.displayManager.sessionPackages = [
      (pkgs.runCommand "driftwm-session" {
          passthru.providedSessions = ["driftwm"];
        } ''
          mkdir -p $out/share/wayland-sessions
          cat <<EOF > $out/share/wayland-sessions/driftwm.desktop
          [Desktop Entry]
          Name=driftwm
          Comment=A trackpad-first infinite canvas Wayland compositor
          Exec=${pkgs.driftwm}/bin/driftwm-session
          Type=Application
          DesktopNames=driftwm
          EOF
        '')
    ];

    xdg.portal = {
      enable = true;
      configPackages = lib.mkDefault [pkgs.driftwm];
      extraPortals = lib.mkDefault [
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gtk
      ];
      # Explicitly route ScreenCast and Screenshot to the wlr portal.
      # Without this, xdg-desktop-portal may pick gtk which has no
      # wlr-screencopy support, causing OBS / PipeWire capture to fail.
      config = {
        sway = {
          default = ["wlr" "gtk"];
          "org.freedesktop.impl.portal.ScreenCast" = "wlr";
          "org.freedesktop.impl.portal.Screenshot" = "wlr";
        };
      };
    };
  };
}
