{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.compat.podman;
  nvidiaEnabled = config.features.core.hardware.nvidia or false;
in {
  options.features.compat.podman = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.compat.enable && false;
    };
    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      inherit (cfg) dockerCompat;
      defaultNetwork.settings.dns_enabled = true;
    };

    hardware.nvidia-container-toolkit.enable = lib.mkIf nvidiaEnabled true;

    environment.systemPackages = [
      pkgs.docker-compose
      pkgs.distrobox
    ];

    systemd.tmpfiles.rules = [
      "L+ /var/run/docker.sock - - - - /run/podman/podman.sock"
    ];
  };
}
