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
            dns.port = effectiveDnsPort;
            dhcp.active = true;
            misc.etc_dnsmasq_d = true;
          };
        };

        services.pihole-web = {
          enable = true;
          hostName = "pihole.${baseDomain}";
          ports = [8080];
        };
      }
    ]
  );
}
