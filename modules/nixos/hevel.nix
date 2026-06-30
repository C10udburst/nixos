{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.systemSettings.hevel;
  # Create a desktop file so SDDM sees it as a session
in {
  options.systemSettings.hevel = {
    enable = lib.mkEnableOption "Enable hevel and mojito packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.neu-nix.packages.${pkgs.system}.hevel
      inputs.neu-nix.packages.${pkgs.system}.mojito
    ];

    # Register the session
    services.displayManager.sessionPackages = [
      (pkgs.runCommand "hevel-session" {
          passthru.providedSessions = ["hevel"];
        } ''
          mkdir -p $out/share/wayland-sessions
          cat <<EOF > $out/share/wayland-sessions/hevel.desktop
          [Desktop Entry]
          Name=Hevel
          Comment=Hevel Wayland Compositor
          Exec=${inputs.neu-nix.packages.${pkgs.system}.hevel}/bin/swc-launch hevel
          Type=Application
          EOF
        '')
    ];
  };
}
