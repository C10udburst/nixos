{
  config,
  lib,
  ...
}: let
  piholeCfg = config.features.server.web.pihole;
  cfg = config.features.server.web.pihole.coredns;
  baseDomain = config.features.server.web.core.baseDomain or "example.com";

  tailscaleAnswers =
    lib.concatMapStrings (
      ip: "        answer \"{{ .Name }} 60 IN A ${ip}\"\n"
    )
    cfg.tailscaleIp;
  localAnswers =
    lib.concatMapStrings (
      ip: "        answer \"{{ .Name }} 60 IN A ${ip}\"\n"
    )
    cfg.localIp;
in {
  options.features.server.web.pihole.coredns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = piholeCfg.enable && true;
    };
    tailscaleIp = lib.mkOption {
      type = lib.types.coercedTo lib.types.str (s: [s]) (lib.types.listOf lib.types.str);
      default = ["100.93.113.91"];
    };
    localIp = lib.mkOption {
      type = lib.types.coercedTo lib.types.str (s: [s]) (lib.types.listOf lib.types.str);
      default = [
        "192.168.1.10"
        "192.168.1.11"
      ];
    };
  };

  config = lib.mkIf (piholeCfg.enable && cfg.enable) {
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];

    services.coredns = {
      enable = true;
      config = ''
        .:53 {
            view tailscale {
                expr incidr(client_ip(), '100.64.0.0/10')
            }
            template IN A ${baseDomain} {
                match .*
        ${tailscaleAnswers}    }
            forward . 127.0.0.1:5354
            cache 30
            errors
        }

        .:53 {
            view local {
                expr true
            }
            template IN A ${baseDomain} {
                match .*
        ${localAnswers}    }
            forward . 127.0.0.1:5354
            cache 30
            errors
        }
      '';
    };
  };
}
