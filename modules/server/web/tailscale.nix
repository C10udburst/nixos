{
  config,
  lib,
  ...
}: let
  cfg = config.features.server.web.tailscale;
  webCfg = config.features.server.web;
in {
  options.features.server.web.tailscale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = webCfg.enable && true;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}.taile505b.ts.net";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.permitCertUid = "caddy";
  };
}
