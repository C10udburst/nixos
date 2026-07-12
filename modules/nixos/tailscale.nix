{
  config,
  lib,
  ...
}: let
  cfg = config.systemSettings.tailscale;
in {
  options.systemSettings.tailscale = {
    enable = lib.mkEnableOption "Enable Tailscale client daemon";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraUpFlags = ["--operator=${config.hostSettings.username or "cloudburst"}"];
    };
    networking.firewall.trustedInterfaces = ["tailscale0"];
  };
}
