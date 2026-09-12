{
  config,
  lib,
  pkgs ? null,
}:
let
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  sablierEnabled = config.features.server.web.sablier.enable or false;
  sablierHostPort = "127.0.0.1:10000";
  sessionDuration = config.features.server.web.sablier.sessionDuration or "15m";

  mkWebApp =
    {
      name,
      aliases ? [ ],
      port ? null,
      socket ? null,
      suspend ? null,
      extraConfig ? "",
    }:
    let
      domain = "${name}.${baseDomain}";
      upstream =
        if socket != null then
          "unix/${socket}"
        else if port != null then
          "127.0.0.1:${toString port}"
        else
          throw "mkWebApp requires either port or socket for ${name}";

      sablierConfig = lib.optionalString (suspend != null && sablierEnabled) ''
        forward_auth ${sablierHostPort} {
          uri /api/strategies/poke?names=${suspend}&session_duration=${sessionDuration}
        }
        handle_errors {
          @down expression `{err.status_code} in [502, 503, 504]`
          handle @down {
            rewrite * /api/strategies/dynamic?names=${suspend}&session_duration=${sessionDuration}&theme=ghost&url=https://{host}{uri}
            reverse_proxy ${sablierHostPort}
          }
        }
      '';
    in
    {
      features.server.web.core._apps = [
        {
          inherit name aliases port;
        }
      ];
      features.server.web.sablier._suspendedUnits = lib.optional (suspend != null) suspend;
      services.caddy.virtualHosts."${domain}" = {
        extraConfig = ''
          ${sablierConfig}
          reverse_proxy ${upstream}
          ${extraConfig}
        '';
      };
    };
in
{
  inherit mkWebApp;
}
