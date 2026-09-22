{
  config,
  lib,
  ...
}: let
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  sablierEnabled = config.features.server.web.sablier.enable or false;
  sablierHostPort = "127.0.0.1:10000";

  homeAncestors = "https://home.${baseDomain}";
  allowedAncestors = "'self' ${homeAncestors}";

  mkWebApp = {
    name,
    aliases ? [],
    port ? null,
    socket ? null,
    suspend ? null,
    extraConfig ? "",
  }: let
    domain = "${name}.${baseDomain}";
    upstream =
      if socket != null
      then "unix/${socket}"
      else if port != null
      then "127.0.0.1:${toString port}"
      else throw "mkWebApp requires either port or socket for ${name}";

    suspendList =
      if suspend == null
      then []
      else if lib.isList suspend
      then suspend
      else [suspend];

    sablierConfig = lib.optionalString (suspendList != [] && sablierEnabled) ''
      forward_auth ${sablierHostPort} {
        uri /api/strategies/poke?group=${name}
        header_up -Content-Type
        header_up -Content-Length
        @failures status 4xx 5xx
        handle_response @failures {
        }
      }
      handle_errors {
        @down expression `{err.status_code} in [502, 503, 504]`
        handle @down {
          rewrite * /api/strategies/dynamic?group=${name}
          method GET
          reverse_proxy ${sablierHostPort} {
            header_up -Content-Type
            header_up -Content-Length
          }
        }
      }
    '';
  in {
    features.server.web.core._apps = [
      {
        inherit name aliases port;
        suspend = suspendList;
      }
    ];
    services.caddy.virtualHosts."${domain}" = {
      useACMEHost = lib.mkIf (config.features.server.web.ssl.enable or false) baseDomain;
      extraConfig = ''
        header -X-Frame-Options
        header ?Content-Security-Policy "frame-ancestors ${allowedAncestors}"

        ${sablierConfig}
        reverse_proxy ${upstream} {
          header_down -X-Frame-Options
          header_down Content-Security-Policy "frame-ancestors 'none'" "frame-ancestors 'self'"
          header_down Content-Security-Policy "frame-ancestors ([^;]+)" "frame-ancestors $1 ${homeAncestors}"
        }
        ${extraConfig}
      '';
    };
  };
in {
  inherit mkWebApp allowedAncestors homeAncestors;
}
