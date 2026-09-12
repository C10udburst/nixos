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

  appKeyPairs = lib.concatMap (
    app:
    map (key: {
      inherit key;
      appName = app.name;
      aliases = app.aliases or [ ];
    }) (lib.unique ([ app.name ] ++ (app.aliases or [ ])))
  ) cfg._apps;
  groupByKey = lib.groupBy (p: p.key) appKeyPairs;
  nameCollisions = lib.filterAttrs (_key: pairs: builtins.length pairs > 1) groupByKey;
  formatNameCollision =
    key: pairs:
    "Domain name/alias \"${key}\" is claimed by multiple web apps: "
    + lib.concatMapStringsSep ", " (
      p:
      if p.aliases != [ ] then
        "${p.appName} (aliases: ${lib.concatStringsSep "/" p.aliases})"
      else
        p.appName
    ) pairs;
  nameCollisionMessages = lib.mapAttrsToList formatNameCollision nameCollisions;

in
{
  config = lib.mkIf cfg.enable {
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
      {
        assertion = nameCollisions == { };
        message =
          "\n"
          + lib.concatStringsSep "\n" (
            [
              "Name or alias collision detected in server.web:"
            ]
            ++ nameCollisionMessages
          );
      }
    ];
  };
}
