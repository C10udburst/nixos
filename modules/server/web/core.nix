{
  config,
  lib,
  ...
}:
let
  cfg = config.features.server.web.core;

  appsWithPorts = lib.filter (a: a.port != null) cfg._apps;
  groupByPort = lib.groupBy (a: toString a.port) appsWithPorts;
  collisions = lib.filterAttrs (_port: apps: builtins.length apps > 1) groupByPort;
  formatCollision =
    port: apps:
    "Port ${port} is used by multiple web apps: ${lib.concatMapStringsSep ", " (a: a.name) apps}";
  collisionMessages = lib.mapAttrsToList formatCollision collisions;

in
{
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
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.enable = true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    assertions = [
      {
        assertion = collisions == { };
        message =
          "\n"
          + lib.concatStringsSep "\n" (
            [
              "Port collision detected in server.web:"
            ]
            ++ collisionMessages
          );
      }
    ];
  };
}
