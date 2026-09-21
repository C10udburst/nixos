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

      # Optimize UDP GRO forwarding for Tailscale on Ethernet (enp0s31f6)
      environment.systemPackages = [pkgs.ethtool];

      systemd.services.tailscale-udp-gro = {
        description = "Enable UDP GRO forwarding on enp0s31f6 for Tailscale";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.ethtool}/bin/ethtool -K enp0s31f6 rx-udp-gro-forwarding on rx-gro-list off";
          RemainAfterExit = true;
        };
      };

      services.udev.extraRules = ''
        ACTION=="add|bind", SUBSYSTEM=="net", KERNEL=="enp0s31f6", RUN+="${pkgs.ethtool}/bin/ethtool -K %k rx-udp-gro-forwarding on rx-gro-list off"
      '';
    })
  ];
}
