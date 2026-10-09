{
  config,
  lib,
  ...
}: let
  piholeCfg = config.features.server.web.pihole;
  cfg = piholeCfg.coredns;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  i2pEnabled = config.features.server.web.i2p or false;

  # Helper to expand short hostnames across common LAN suffix domains
  withLocalSuffixes = name: target:
    lib.listToAttrs (
      map
      (suffix: {
        name = "${name}${suffix}";
        value = target;
      })
      [
        ""
        ".local"
        ".lan"
        ".home"
      ]
    );

  cnameTemplates = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (alias: target: ''
      template IN ANY ${alias} {
          answer "{{ .Name }} 60 IN CNAME ${target}."
      }
    '')
    cfg.cname
  );

  domainTemplates = viewName:
    lib.concatStringsSep "\n" (
      lib.filter (s: s != "") (
        lib.mapAttrsToList (
          domain: viewIps: let
            ips = viewIps.${viewName} or [];
            extraZones = lib.optionalString (
              domain == baseDomain
            ) " ${config.networking.hostName}${lib.optionalString i2pEnabled " i2p"}";
          in
            lib.optionalString (ips != []) ''
              template IN A ${domain}${extraZones} {
                  match .*
              ${lib.concatMapStrings (ip: "    answer \"{{ .Name }} 60 IN A ${ip}\"\n") ips}}
            ''
        )
        cfg.domains
      )
    );

  # Shared template block generator for CoreDNS views
  mkView = {
    name,
    expr,
  }: ''
    .:53 {
        view ${name} {
            expr ${expr}
        }
        ${cnameTemplates}
        ${domainTemplates name}
        template IN A myip.local {
            answer "{{ .Name }} 0 IN A {{ .Remote }}"
        }
        rewrite edns0 subnet set 32 128
        forward . 127.0.0.1:5354
        cache 30
        errors
    }
  '';
in {
  options.features.server.web.pihole.coredns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = piholeCfg.enable;
    };
    domains = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            local = lib.mkOption {
              type = lib.types.coercedTo lib.types.str lib.singleton (lib.types.listOf lib.types.str);
              default = [];
            };
            tailscale = lib.mkOption {
              type = lib.types.coercedTo lib.types.str lib.singleton (lib.types.listOf lib.types.str);
              default = [];
            };
          };
        }
      );
      default = {
        "${baseDomain}" = {
          local = [
            "192.168.1.10"
            "192.168.1.11"
          ];
          tailscale = ["100.96.233.27"];
        };
        "llm.wilkins.pl.eu.org" = {
          local = [];
          tailscale = ["100.126.72.97"];
        };
      };
    };
    cname = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default =
        {
          "${config.features.server.web.tailscale.domain}" = baseDomain;
          "pi.hole" = "pihole.${baseDomain}";
        }
        // withLocalSuffixes config.networking.hostName baseDomain
        // withLocalSuffixes "go" "go.${baseDomain}"
        // withLocalSuffixes "homeassistant" "hass.${baseDomain}"
        // withLocalSuffixes "i2prouter" "i2p.${baseDomain}"
        // withLocalSuffixes "llm" "llm.wilkins.pl.eu.org"
        // withLocalSuffixes "llm-x2" "llm.wilkins.pl.eu.org";
    };
  };

  config = lib.mkIf (piholeCfg.enable && cfg.enable) {
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];

    services.coredns = {
      enable = true;
      config = lib.concatStringsSep "\n" [
        (mkView {
          name = "tailscale";
          expr = "incidr(client_ip(), '100.64.0.0/10')";
        })
        (mkView {
          name = "local";
          expr = "true";
        })
      ];
    };
  };
}
