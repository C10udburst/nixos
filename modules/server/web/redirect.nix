{
  config,
  lib,
  ...
}: let
  cfg = config.features.server.web.redirect;
  webCfg = config.features.server.web;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  apps = config.features.server.web.core._apps or [];

  tailscaleCfg = config.features.server.web.tailscale or {};
  tailscaleDomain =
    if (tailscaleCfg.enable or false) && (tailscaleCfg.domain or "") != ""
    then tailscaleCfg.domain
    else null;

  wildcardVhosts = lib.concatStringsSep ", " (
    [
      "https://${baseDomain}"
      "https://*.${baseDomain}"
    ]
    ++ (map (d: "https://${d}") (cfg.extraDomains or []))
  );

  appRedirectRules =
    lib.concatMapStrings (app: let
      allKeys = lib.unique ([app.name] ++ (app.aliases or []));
      regexPattern = lib.concatStringsSep "|" allKeys;
      safeName = lib.replaceStrings ["-"] ["_"] app.name;
    in ''
      @sub_${safeName} header_regexp host ^(${regexPattern})\.
      handle @sub_${safeName} {
        redir https://${app.name}.${baseDomain}{uri} 302
      }

      @path_${safeName} path_regexp path ^/(${regexPattern})(/.*)?$
      handle @path_${safeName} {
        route {
          uri strip_prefix /{re.path.1}
          redir https://${app.name}.${baseDomain}{uri} 302
        }
      }
    '')
    apps;
in {
  options.features.server.web.redirect = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = webCfg.enable && true;
    };
    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = lib.mkMerge [
      {
        "http://" = {
          extraConfig = ''
            redir https://{host}{uri} 308
          '';
        };
        "${wildcardVhosts}" = {
          extraConfig = ''
            ${appRedirectRules}
            handle {
              redir https://home.${baseDomain} 302
            }
          '';
        };
      }
      (lib.mkIf (tailscaleDomain != null) {
        "https://${tailscaleDomain}" = {
          extraConfig = ''
            ${appRedirectRules}
            handle {
              redir https://home.${baseDomain} 302
            }
          '';
        };
      })
    ];
  };
}
