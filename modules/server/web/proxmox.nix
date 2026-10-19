{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.proxmox;
  webHelper = import ./_webService.nix {inherit config lib pkgs;};
  localPort = 8006;
in {
  options.features.server.web.proxmox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.server.web.enable && true;
    };
    bastionHost = lib.mkOption {
      type = lib.types.str;
      default = "nixos-lxc";
    };
    bastionUser = lib.mkOption {
      type = lib.types.str;
      default = "cloudburst";
    };
    targetHost = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.69";
    };
    targetPort = lib.mkOption {
      type = lib.types.int;
      default = 8006;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (webHelper.mkWebApp {
        name = "proxmox";
        aliases = [
          "pve"
        ];
        port = localPort;
        cors = true;
        extraProxyConfig = ''
          transport http {
            tls_insecure_skip_verify
          }
        '';
      })
      {
        systemd.services.proxmox-tunnel = {
          description = "SSH tunnel to Proxmox Web UI via bastion";
          after = [
            "network-online.target"
            "tailscale.service"
          ];
          wants = [
            "network-online.target"
          ];
          wantedBy = [
            "multi-user.target"
          ];
          serviceConfig = {
            User = "cloudburst";
            ExecStart = "${pkgs.openssh}/bin/ssh -NT -L 127.0.0.1:${toString localPort}:${cfg.targetHost}:${toString cfg.targetPort} -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new ${cfg.bastionUser}@${cfg.bastionHost}";
            Restart = "always";
            RestartSec = "5s";
          };
        };
      }
    ]
  );
}
