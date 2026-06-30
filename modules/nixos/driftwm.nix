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
