{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homeSettings.tailscale;
in {
  options.homeSettings.tailscale = {
    enable = lib.mkEnableOption "Enable Tailscale Home Manager integration";
  };

  config = lib.mkIf cfg.enable {
    # systemd.user.services.tailscale-systray = {
    #   Unit = {
    #     Description = "Tailscale System Tray";
    #     After = ["graphical-session.target"];
    #     PartOf = ["graphical-session.target"];
    #   };

    #   Service = {
    #     ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
    #     Restart = "on-failure";
    #   };

    #   Install = {
    #     WantedBy = ["graphical-session.target"];
    #   };
    # };
  };
}
