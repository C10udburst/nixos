{
  config,
  lib,
  ...
}: let
  cfg = config.features.server.web.core;
in {
  options.features.server.web.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "brix0.wilkins.pl.eu.org";
    };
    _apps = lib.mkOption {
      internal = true;
      type = lib.types.listOf lib.types.attrs;
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.enable = true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
