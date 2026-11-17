{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.services.flaresolverr;
in {
  options.features.services.flaresolverr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.services.enable && false;
    };
    # Served to clients on the loopback only: the solver's browser is handed the same
    # provider sessions as the apps using it, so it stays off the LAN.
    port = lib.mkOption {
      type = lib.types.port;
      default = 8191;
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.flaresolverr = {
      isSystemUser = true;
      group = "flaresolverr";
      # Rootless podman keeps its image store under the home directory.
      home = "/var/lib/flaresolverr";
      autoSubUidGidRange = true;
      linger = true;
    };
    users.groups.flaresolverr = {};

    systemd.tmpfiles.rules = [
      "d /var/lib/flaresolverr 0750 flaresolverr flaresolverr - -"
    ];

    virtualisation.oci-containers.containers.flaresolverr = {
      image = helpers.resolveImage "ghcr.io/flaresolverr/flaresolverr:latest";
      podman.user = "flaresolverr";
      ports = [
        "127.0.0.1:${toString cfg.port}:8191"
      ];
      environment = {
        LOG_LEVEL = "info";
        TZ = config.time.timeZone;
      };
    };
  };
}
