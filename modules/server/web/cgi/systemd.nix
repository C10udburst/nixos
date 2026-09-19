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
        "tailscaled"
        "sshd"
        "caddy"
        "fcgiwrap-cgi"
        "coredns"
        "podman-sablier"
        "copyparty"
        "duplicati"
        "podman-eightmb"
        "fetlife"
        "gitea"
        "glances"
        "golink"
        "podman-homarr"
        "podman-homeassistant"
        "esphome"
        "immich-server"
        "immich-machine-learning"
        "karakeep-web"
        "karakeep-workers"
        "manyfold"
        "meilisearch"
        "organizeer"
        "pihole-ftl"
        "podman-resume"
        "siyuan"
        "podman-transmute"
        "vaultwarden"
        "podman-wealthfolio"
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
