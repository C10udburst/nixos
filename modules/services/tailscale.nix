{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.services.tailscale;
in {
  options.features.services.tailscale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        if config.features.services.enable
        then true
        else false;
    };
    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
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
    (lib.mkIf (config.features.services.enable && cfg.enable) {
      services.tailscale = {
        enable = true;
        extraUpFlags = ["--operator=cloudburst"] ++ lib.optionals cfg.exitNode ["--advertise-exit-node"];
      };

      networking.firewall.trustedInterfaces = ["tailscale0"];

      boot.kernel.sysctl = lib.mkIf cfg.exitNode {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
    })
  ];
}
