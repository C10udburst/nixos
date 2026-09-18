# Google (ECS, DNSSEC);8.8.8.8;8.8.4.4;2001:4860:4860:0:0:0:0:8888;2001:4860:4860:0:0:0:0:8844
# OpenDNS (ECS, DNSSEC);208.67.222.222;208.67.220.220;2620:119:35::35;2620:119:53::53
# Level3;4.2.2.1;4.2.2.2;;
# Comodo;8.26.56.26;8.20.247.20;;
# DNS.WATCH (DNSSEC);84.200.69.80;84.200.70.40;2001:1608:10:25:0:0:1c04:b12f;2001:1608:10:25:0:0:9249:d69b
# Quad9 (filtered, DNSSEC);9.9.9.9;149.112.112.112;2620:fe::fe;2620:fe::9
# Quad9 (unfiltered, no DNSSEC);9.9.9.10;149.112.112.10;2620:fe::10;2620:fe::fe:10
# Quad9 (filtered, ECS, DNSSEC);9.9.9.11;149.112.112.11;2620:fe::11;2620:fe::fe:11
# Cloudflare (DNSSEC);1.1.1.1;1.0.0.1;2606:4700:4700::1111;2606:4700:4700::1001
# ControlD (Uncensored);76.76.2.5;76.76.10.5;2606:1a40::5;2606:1a40:1::5
# OpenNIC;185.226.181.19;195.10.195.195;2a00:f826:8:2::195;2001:470:71:6dc::53
# DNS.SB;185.222.222.222;45.11.45.11;2a09::;2a11::"
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.pihole;
  storage = config.features.server.web.storage;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";
  webHelper = import ../_webService.nix {inherit config lib pkgs;};
  corednsEnabled = cfg.coredns.enable or cfg.coredns or false;

  effectiveDnsPort =
    if corednsEnabled
    then 5354
    else 53;
in {
  options.features.server.web.pihole = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # dns.watch
        "84.200.69.80"
        "84.200.70.40"
        "2001:1608:10:25:0:0:1c04:b12f"
        "2001:1608:10:25:0:0:9249:d69b"
        # OpenNIC
        "185.226.181.19"
        "195.10.195.195"
        "2a00:f826:8:2::195"
        "2001:470:71:6dc::53"
        # DNS.SB
        "185.222.222.222"
        "45.11.45.11"
        "2a09::"
        "2a11::"
      ];
    };
    dnsServers = lib.mkOption {
      type = lib.types.coercedTo lib.types.str (s: [s]) (lib.types.listOf lib.types.str);
      default = [
        "192.168.1.10"
        "192.168.1.11"
        "192.168.1.1"
      ];
    };
    dhcpServer = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.10";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "pihole";
        aliases = [
          "pi"
          "dns"
        ];
        port = 8080;
      })
      {
        environment.etc = {
          "dnsmasq.d/dhcp-dns.conf".text = ''
            dhcp-option=option:dns-server,${lib.concatStringsSep "," cfg.dnsServers}
          '';
          "dnsmasq.d/dhcp-server-id.conf".text = ''
            dhcp-option=54,${cfg.dhcpServer}
          '';
          "dnsmasq.d/dhcp-ntp.conf".text = ''
            dhcp-option=option:ntp-server,192.168.1.1
          '';
        };

        services.pihole-ftl = {
          enable = true;
          stateDirectory = "${storage}/pihole";
          openFirewallDNS = !corednsEnabled;
          openFirewallDHCP = true;
          settings = {
            dns = {
              domain.name = "home";
              upstreams = cfg.upstreams;
              port = effectiveDnsPort;
              listeningMode = "ALL";
              rateLimit = 10000;
              EDNS0ECS = true;
            };
            dhcp = {
              active = true;
              start = "192.168.1.50";
              end = "192.168.1.250";
              router = "192.168.1.1";
              netmask = "255.255.255.0";
              leaseTime = "1w";
            };
            misc = {
              etc_dnsmasq_d = true;
            };
          };
        };

        systemd.services.pihole-ftl.preStart = let
          gravityDB = config.services.pihole-ftl.settings.files.gravity;
          ftlBin = lib.getExe config.services.pihole-ftl.package;
          schema = "${config.services.pihole-ftl.piholePackage}/share/pihole/advanced/Templates/gravity.db.sql";
        in ''
          # Ensure gravity database exists and has required schema/tables
          if [ ! -s "${gravityDB}" ] || ! ${ftlBin} sqlite3 -ni "${gravityDB}" "SELECT 1 FROM \"group\" LIMIT 1;" >/dev/null 2>&1; then
            echo "Initializing Pi-hole gravity database schema at ${gravityDB}..."
            ${ftlBin} sqlite3 -ni "${gravityDB}" < "${schema}"
            ${ftlBin} sqlite3 -ni "${gravityDB}" "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'Default StevenBlack blocklist');"
          fi
        '';

        services.pihole-web = {
          enable = true;
          hostName = "pihole.${baseDomain}";
          ports = [8080];
        };
      }
    ]
  );
}
