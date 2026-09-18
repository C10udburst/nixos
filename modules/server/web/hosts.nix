{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web;
  hostsCfg = cfg.hosts;
  apps = cfg.core._apps or [];

  toSubdomain = sub: "${sub}.${cfg.core.baseDomain}";

  allDomains =
    [
      cfg.core.baseDomain
    ]
    ++ lib.map (app: toSubdomain app.name) apps
    ++ lib.concatMap (app: lib.map toSubdomain (app.aliases or [])) apps;

  containerHosts = pkgs.writeText "containers-hosts" ''
    127.0.0.1 localhost
    ::1 localhost
    127.0.0.2 ${config.networking.hostName}
    169.254.1.2 ${lib.concatStringsSep " " allDomains}
    10.88.0.1 ${lib.concatStringsSep " " allDomains}
    172.17.0.1 ${lib.concatStringsSep " " allDomains}
  '';
in {
  options.features.server.web.hosts = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable && true;
  };

  config = lib.mkIf hostsCfg {
    # Container-level resolution mapped to host gateway IPs across container runtimes:
    # 169.254.1.2: Rootless Podman (pasta / slirp4netns)
    # 10.88.0.1:   Rootful Podman (default bridge)
    # 172.17.0.1:  Docker / docker-compose (default bridge)
    virtualisation.containers.containersConf.settings = {
      containers.base_hosts_file = "${containerHosts}";
    };
  };
}
