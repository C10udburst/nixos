{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.server.web.cgi;
  systemdCfg = cfg.systemd;
in {
  options.features.server.web.cgi.systemd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable && true;
    };

    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "caddy"
        "copyparty"
        "coredns"
        "duplicati"
        "esphome"
        "fcgiwrap-cgi"
        "fetlife"
        "gitea"
        "glances"
        "golink"
        "immich-machine-learning"
        "immich-server"
        "karakeep-web"
        "karakeep-workers"
        "meilisearch"
        "organizeer"
        "pihole-ftl"
        "podman-eightmb"
        "podman-homarr"
        "podman-homeassistant"
        "podman-manyfold"
        "podman-resume"
        "podman-sablier"
        "podman-transmute"
        "podman-wealthfolio"
        "postgres"
        "siyuan"
        "sshd"
        "tailscaled"
        "vaultwarden"
      ];
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
