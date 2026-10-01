{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  webCfg = config.features.server.web;
  baseDomain = webCfg.core.baseDomain or "example.com";
  domain = "cgi.${baseDomain}";
  webHelper = import ../_webService.nix {inherit config lib pkgs;};

  scriptRoutes = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: s: ''
      @${name} path /${name} /${name}/* /${name}.py /${name}.cgi /${name}.html /${name}.json
      handle @${name} {
        reverse_proxy unix//run/fcgiwrap-cgi.sock {
          transport fastcgi {
            env SCRIPT_FILENAME ${s.script}
          }
          header_down -X-Frame-Options
          header_down Content-Security-Policy "frame-ancestors 'none'" "frame-ancestors 'self'"
          header_down Content-Security-Policy "frame-ancestors ([^;]+)" "frame-ancestors $1 ${webHelper.homeAncestors}"
        }
      }
    '')
    cfg.scripts
  );

  indexRoute = lib.optionalString (cfg.indexHtml != null) ''
    handle / {
      root * ${cfg.indexHtml}
      file_server
    }

    handle /index* {
      root * ${cfg.indexHtml}
      rewrite * /index.html
      file_server
    }
  '';

  cgiBinRoute = ''
    @cgiBin path /cgi-bin /cgi-bin/*
    handle @cgiBin {
      route {
        uri strip_prefix /cgi-bin
        redir {uri} 302
      }
    }
  '';
in {
  options.features.server.web.cgi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = webCfg.enable && true;
    };

    indexHtml = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
    };

    scripts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          {name, ...}: {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
              };
              script = lib.mkOption {
                type = lib.types.either lib.types.package (lib.types.either lib.types.path lib.types.str);
              };
            };
          }
        )
      );
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    features.server.web.core._apps = [
      {
        name = "cgi";
        aliases = [
          "misc"
        ];
        port = null;
      }
    ];

    services.fcgiwrap.instances.cgi = {
      process.user = "caddy";
      process.group = "caddy";
      socket = {
        type = "unix";
        address = "/run/fcgiwrap-cgi.sock";
        user = "caddy";
        group = "caddy";
        mode = "0660";
      };
    };

    services.caddy.virtualHosts."${domain}" = {
      useACMEHost = lib.mkIf (config.features.server.web.ssl.enable or false) baseDomain;
      extraConfig = ''
        log error_cgi {
          output file /var/log/caddy/error-cgi.log {
            roll_size 10MB
            roll_keep 10
            roll_keep_for 720h
          }
          format json
          no_hostname
        }

        header -X-Frame-Options
        header ?Content-Security-Policy "frame-ancestors ${webHelper.allowedAncestors}"

        handle_errors {
          log_name error_cgi
        }

        ${cgiBinRoute}
        ${indexRoute}
        ${scriptRoutes}
      '';
    };
  };
}
