{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.services.tailscale;
in {
  options.features.services.tailscale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.services.enable && true;
    };
    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    udpGro = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
    };
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        tailcat = {
          url = "github:tailscale/tailcat";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    }
    (lib.mkIf cfg.enable {
      services.tailscale = {
        enable = true;
        authKeyFile = lib.mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
        extraUpFlags =
          [
            "--operator=cloudburst --accept-routes"
          ]
          ++ lib.optionals cfg.exitNode ["--advertise-exit-node"];
      };

      networking.firewall.trustedInterfaces = ["tailscale0"];
    })
    (lib.mkIf (cfg.enable && cfg.exitNode) {
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      environment.systemPackages = [pkgs.ethtool];

      systemd.services.tailscale-udp-gro = lib.mkIf cfg.udpGro {
        description = "Enable UDP GRO forwarding for Tailscale exit node";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "tailscale-udp-gro" ''
            set -eu
            ${
              if cfg.interface != null
              then ''
                ${pkgs.ethtool}/bin/ethtool -K "${cfg.interface}" rx-udp-gro-forwarding on rx-gro-list off || true
              ''
              else ''
                DEVS=$((${pkgs.iproute2}/bin/ip -4 -o route get 8.8.8.8 2>/dev/null || true; ${pkgs.iproute2}/bin/ip -6 -o route get 2001:4860:4860::8888 2>/dev/null || true) \
                  | ${pkgs.gawk}/bin/awk '{for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1)}' \
                  | ${pkgs.coreutils}/bin/sort -u)

                for dev in $DEVS; do
                  ${pkgs.ethtool}/bin/ethtool -K "$dev" rx-udp-gro-forwarding on rx-gro-list off || true
                done
              ''
            }
          '';
          RemainAfterExit = true;
        };
      };

      services.udev.extraRules = lib.mkIf (cfg.udpGro && cfg.interface != null) ''
        ACTION=="add|bind", SUBSYSTEM=="net", KERNEL=="${cfg.interface}", RUN+="${pkgs.ethtool}/bin/ethtool -K %k rx-udp-gro-forwarding on rx-gro-list off"
      '';
    })
  ];
}
