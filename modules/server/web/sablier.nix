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
  targetUnits = lib.unique (
    lib.concatMap (
      app:
        map (s:
          if lib.hasSuffix ".service" s
          then s
          else "${s}.service")
        app.suspend
    )
    suspendedApps
  );

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

        sablier-suspend = lib.mkIf (targetUnits != []) {
          description = "Suspend all Sablier-managed services after boot or rebuild";
          wantedBy = ["multi-user.target"];
          after =
            [
              "podman-sablier.service"
              "network.target"
            ]
            ++ targetUnits;
          wants = ["podman-sablier.service"];
          restartTriggers = [
            (pkgs.writeText "sablier-suspended-units" (builtins.toJSON targetUnits))
          ];
          path = [
            pkgs.curl
            pkgs.systemd
            pkgs.coreutils
            pkgs.util-linux
            pkgs.gnugrep
          ];
          serviceConfig = {
            Type = "simple";
            RemainAfterExit = false;
            Restart = "no";
          };
          script = ''
            # If a rebuild is in progress, wait for switch-to-configuration to completely finish
            if [ -f /run/nixos/switch-to-configuration.lock ]; then
              echo "Waiting for nixos-rebuild to finish..."
              flock -s /run/nixos/switch-to-configuration.lock true || true
            fi

            # Wait for pending systemd jobs to finish
            echo "Waiting for pending systemd jobs..."
            for i in $(seq 1 60); do
              if ! systemctl list-jobs --no-legend 2>/dev/null | grep -v "sablier-suspend" | grep -q .; then
                break
              fi
              sleep 1
            done

            # Let services settle before suspending
            sleep 5

            # Wait for Sablier daemon to be healthy
            for i in $(seq 1 30); do
              if curl -s http://127.0.0.1:10000/health | grep -q "OK"; then
                break
              fi
              sleep 1
            done

            for unit in ${lib.concatStringsSep " " targetUnits}; do
              if systemctl is-active --quiet "$unit"; then
                echo "Suspending Sablier service: $unit"
                systemctl stop "$unit" || true
              fi
            done
          '';
        };
      }
    ];

    system.activationScripts.sablier-suspend = lib.mkIf (targetUnits != []) {
      supportsDryActivation = true;
      text = ''
        if [ "$NIXOS_ACTION" = "dry-activate" ]; then
          mkdir -p /run/nixos
          echo "sablier-suspend.service" >> /run/nixos/dry-activation-restart-list
        else
          mkdir -p /run/nixos
          echo "sablier-suspend.service" >> /run/nixos/activation-restart-list
        fi
      '';
    };
  };
}
