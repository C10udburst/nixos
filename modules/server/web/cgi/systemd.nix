{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  systemdCfg = cfg.systemd;
  apps = config.features.server.web.core._apps or [];
  suspendedApps = lib.filter (app: (app.suspend or []) != []) apps;
  targetUnits = lib.unique (
    lib.concatMap (app: map (lib.removeSuffix ".service") app.suspend) suspendedApps
  );
in {
  options.features.server.web.cgi.systemd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };

    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        [
          "caddy"
          "copyparty"
          "coredns"
          "duplicati"
          "fcgiwrap-cgi"
          "gitea"
          "golink"
          "organizeer"
          "pihole-ftl"
          "podman-homarr"
          "podman-homeassistant"
          "podman-sablier"
          "postgres"
          "sshd"
          "tailscaled"
        ]
        ++ targetUnits;
    };
  };

  config = lib.mkIf (cfg.enable && systemdCfg.enable) {
    features.server.web.cgi.scripts.systemd.script = pkgs.writeShellScript "systemd-status" ''
      export SYSTEMCTL="${pkgs.systemd}/bin/systemctl"
      export SYSTEMD_SERVICES='${builtins.toJSON systemdCfg.services}'
      exec ${pkgs.python3}/bin/python3 ${./_scripts/systemd.py} "$@"
    '';
  };
}
