{
  config,
  lib,
  pkgs,
  helpers,
  ...
}: let
  cfg = config.features.server.web.sablier;
  webCfg = config.features.server.web;
  storage = webCfg.storage;
  apps = webCfg.core._apps or [];
  suspendedApps = lib.filter (app: (app.suspend or []) != []) apps;

  configFile = (pkgs.formats.yaml {}).generate "sablier.yaml" {
    provider = {
      name = "systemd";
      systemd = {
        user-instance = false;
      };
    };
    server = {
      port = 10000;
    };
    storage = {
      file = "${storage}/sablier/state.json";
    };
    sessions = {
      default-duration = cfg.sessionDuration;
      expiration-interval = "20s";
    };
    logging = {
      level = "info";
    };
    strategy = {
      dynamic = {
        show-details-by-default = true;
        default-theme = "ghost";
        default-refresh-frequency = "5s";
      };
      blocking = {
        default-timeout = "1m";
      };
    };
  };
in {
  options.features.server.web.sablier = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = webCfg.enable && true;
    };
    sessionDuration = lib.mkOption {
      type = lib.types.str;
      default = "15m";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${storage}/sablier 2750 root web - -"
      "L+ ${storage}/sablier/sablier.yaml - - - - ${configFile}"
    ];

    virtualisation.oci-containers.containers.sablier = {
      image = helpers.resolveImage "ghcr.io/sablierapp/sablier:latest";
      extraOptions = [
        "--network=host"
      ];
      volumes = [
        "${configFile}:/etc/sablier/sablier.yaml:ro"
        "/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket"
        "/run/dbus/system_bus_socket:/run/dbus/system_bus_socket"
        "/etc/systemd/system:/etc/systemd/system:ro"
        "/nix/store:/nix/store:ro"
        "${storage}/sablier:${storage}/sablier"
      ];
      cmd = [
        "start"
        "--configFile=/etc/sablier/sablier.yaml"
      ];
    };

    systemd.services = lib.mkMerge [
      (lib.mkMerge (
        map (
          app:
            lib.genAttrs (map (lib.removeSuffix ".service") (lib.unique app.suspend)) (_name: {
              serviceConfig."X-Sablier-Section = true\n\n[X-Sablier]\nEnable = true\nGroup" = app.name;
            })
        )
        suspendedApps
      ))
      {
        podman-sablier = {
          restartTriggers = [
            configFile
            (pkgs.writeText "sablier-suspended-apps" (
              builtins.toJSON (map (a: {inherit (a) name suspend;}) suspendedApps)
            ))
          ];
        };

        sablier-rebuild-poke = lib.mkIf (suspendedApps != []) {
          description = "Poke all Sablier groups after system rebuild";
          wantedBy = ["multi-user.target"];
          after = [
            "podman-sablier.service"
            "network.target"
          ];
          wants = ["podman-sablier.service"];
          restartTriggers = [
            (pkgs.writeText "sablier-groups" (builtins.toJSON (map (a: a.name) suspendedApps)))
          ];
          path = [
            pkgs.curl
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = false;
            Restart = "on-failure";
            RestartSec = "2s";
          };
          script = ''
            for i in $(seq 1 30); do
              if curl -s http://127.0.0.1:10000/health | grep -q "OK"; then
                break
              fi
              sleep 1
            done

            ${lib.concatMapStringsSep "\n" (app: ''
                echo "Poking Sablier group: ${app.name}"
                curl -fsSL "http://127.0.0.1:10000/api/strategies/poke?group=${app.name}?session_duration=10m" || true
              '')
              suspendedApps}
          '';
        };
      }
    ];
  };
}
