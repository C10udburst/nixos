{
  config,
  lib,
  ...
}:
let
  cfg = config.features.server.web.redirect;
  webCfg = config.features.server.web;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  apps = config.features.server.web.core._apps or [ ];

  tailscaleCfg = config.features.server.web.tailscale or { };
  tailscaleDomain =
    if (tailscaleCfg.enable or false) && (tailscaleCfg.domain or "") != ""
    then tailscaleCfg.domain
    else null;

  vhosts = lib.concatStringsSep ", " (
    [
      "http://"
      "https://${baseDomain}"
      "https://*.${baseDomain}"
    ]
    ++ lib.optional (tailscaleDomain != null) "https://${tailscaleDomain}"
    ++ (map (d: "https://${d}") (cfg.extraDomains or [ ]))
  );

  appRedirectRules = lib.concatMapStrings (app: let
    allKeys = lib.unique ([ app.name ] ++ (app.aliases or [ ]));
    regexPattern = lib.concatStringsSep "|" allKeys;
    safeName = lib.replaceStrings [ "-" ] [ "_" ] app.name;
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
  '') apps;
in
{
  options.features.server.web.redirect = lib.mkOption {
    type = lib.types.coercedTo lib.types.bool (b: { enable = b; }) (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = webCfg.enable && true;
          };
          extraDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      }
    );
    default = { };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts."${vhosts}" = {
      extraConfig = ''
        ${appRedirectRules}
        handle {
          redir https://home.${baseDomain} 302
        }
      '';
    };
  };
}
