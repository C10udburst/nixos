{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemSettings.waypipe;
in {
  options.systemSettings.waypipe = {
    enable = lib.mkEnableOption "Install waypipe and configure SSH for Wayland application forwarding";
  };

  config = lib.mkIf cfg.enable {
    # waypipe must be present on the *server* side so the client can invoke it
    # via `waypipe ssh user@host`.  Having it in system packages ensures it is
    # always on PATH for any login session.
    environment.systemPackages = [pkgs.waypipe];

    # StreamLocalBindUnlink — automatically remove a stale Unix-domain socket
    # before binding a new one.  Waypipe forwards Wayland sockets over SSH
    # ControlMaster/Unix sockets; without this a leftover socket from a
    # previous (crashed) session blocks reconnection.
    services.openssh.extraConfig = ''
      StreamLocalBindUnlink yes
    '';
  };
}
