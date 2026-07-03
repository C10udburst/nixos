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
    systemd.packages = [pkgs.driftwm];

    # Enable KWallet auto-unlocking in SDDM
    security.pam.services.sddm.kwallet.enable = true;

    # Inherit keyring mode in display-manager systemd service
    systemd.services.display-manager.serviceConfig.KeyringMode = "inherit";

    # Fix empty "Open With" / default apps in Dolphin and Konsole when running
    # outside of a full Plasma session. KDE service discovery (kbuildsycoca6)
    # looks for the applications menu under the XDG_MENU_PREFIX name; outside
    # Plasma this prefix is not set, so we provide the symlink directly.
    environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

    # Ensure kservice can rebuild the sycoca cache and find app entries
    environment.systemPackages = [pkgs.kdePackages.kservice];

    # Set XDG_MENU_PREFIX so KDE apps inside DriftWM find the Plasma app menu
    environment.sessionVariables.XDG_MENU_PREFIX = "plasma-";

    # Register the session
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
  };
}
