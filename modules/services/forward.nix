{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.services.forward;

  isPortOnly = s: builtins.isInt s || builtins.match "^:?[0-9]+$" (toString s) != null;
  isTailscaleOrLocal = s:
    lib.hasPrefix "100." (toString s)
    || lib.hasPrefix "127." (toString s)
    || lib.hasPrefix "0.0.0.0" (toString s)
    || lib.hasPrefix "::" (toString s);

  cleanListen = s: let
    str = toString s;
  in
    if lib.hasPrefix ":" str
    then lib.removePrefix ":" str
    else str;

  normalize = m:
    if m ? from || m ? listen
    then [(m // {name = "default";})]
    else if builtins.isList m
    then lib.imap0 (i: v: v // {name = v.name or "entry-${toString i}";}) m
    else lib.mapAttrsToList (name: value: value // {inherit name;}) m;

  expandEntry = entry:
    if entry ? to && builtins.isList entry.to
    then
      lib.imap0 (i: t:
        entry
        // {
          to = t;
          name = "${entry.name}-${toString i}";
          _expanded = true;
        })
      entry.to
    else if entry ? listen && builtins.isList entry.listen
    then
      lib.imap0 (i: l:
        entry
        // {
          listen = l;
          name = "${entry.name}-${toString i}";
          _expanded = true;
        })
      entry.listen
    else [entry];

  resolveEntry = entry: let
    rawBase =
      if entry ? listen && entry ? target
      then {
        listen = cleanListen entry.listen;
        target = toString entry.target;
      }
      else if entry ? from && entry ? to
      then
        if isPortOnly entry.from || isTailscaleOrLocal entry.from
        then {
          listen = cleanListen entry.from;
          target = toString entry.to;
        }
        else {
          listen = cleanListen entry.to;
          target = toString entry.from;
        }
      else throw "features.services.forward: each mapping requires either 'from' & 'to', or 'listen' & 'target'.";

    listenPort = lib.last (lib.splitString ":" rawBase.listen);

    target = let
      targetParts = lib.splitString ":" rawBase.target;
      targetHost = lib.head targetParts;
      targetPort =
        if builtins.length targetParts > 1
        then lib.last targetParts
        else listenPort;
    in
      if (entry ? _expanded && entry._expanded)
      then "${targetHost}:${listenPort}"
      else "${targetHost}:${targetPort}";

    port = lib.toInt listenPort;
    safeName = lib.replaceStrings ["." ":" "/"] ["-" "-" "-"] "${entry.name}-${rawBase.listen}";
  in {
    inherit port safeName target;
    listen = rawBase.listen;
    name = entry.name;
  };

  entries = map resolveEntry (lib.concatMap expandEntry (normalize cfg.map));

  socketUnits = lib.listToAttrs (map (e: let
      hasTailscale = lib.hasPrefix "100." e.listen;
    in {
      name = "forward-${e.safeName}";
      value = {
        description = "Forward socket for ${e.listen} -> ${e.target}";
        wantedBy = ["sockets.target"];
        listenStreams = [e.listen];
        after = lib.optionals (hasTailscale && config.services.tailscale.enable) ["tailscaled.service"];
        wants = lib.optionals (hasTailscale && config.services.tailscale.enable) ["tailscaled.service"];
        socketConfig = {
          FreeBind = true;
        };
      };
    })
    entries);

  serviceUnits = lib.listToAttrs (map (e: let
      hasTailscale = lib.hasPrefix "100." e.listen || lib.hasPrefix "100." e.target;
    in {
      name = "forward-${e.safeName}";
      value = {
        description = "Forward proxy for ${e.listen} -> ${e.target}";
        requires = ["forward-${e.safeName}.socket"];
        after =
          ["forward-${e.safeName}.socket" "network.target"]
          ++ lib.optionals (hasTailscale && config.services.tailscale.enable) ["tailscaled.service"];
        wants = lib.optionals (hasTailscale && config.services.tailscale.enable) ["tailscaled.service"];
        serviceConfig = {
          Type = "notify";
          ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${e.target}";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    })
    entries);
in {
  options.features.services.forward = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.map != [] && cfg.map != {};
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    map = lib.mkOption {
      type = lib.types.either (lib.types.listOf lib.types.attrs) (lib.types.attrsOf lib.types.unspecified);
      default = {};
    };
  };

  config = lib.mkIf (cfg.enable && entries != []) {
    systemd.sockets = socketUnits;
    systemd.services = serviceUnits;

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall (
      lib.unique (map (e: e.port) entries)
    );
  };
}
