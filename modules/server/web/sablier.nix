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

  sablierSuspendScript = pkgs.writeShellApplication {
    name = "sablier-suspend";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.curl
      pkgs.systemd
    ];
    text = ''
      # Wait for pending systemd jobs to finish
      echo "Waiting for pending systemd jobs..."
      attempts=60
      while [ "$attempts" -gt 0 ]; do
        if ! systemctl list-jobs --no-legend 2>/dev/null | grep -v "sablier-suspend" | grep -q .; then
          break
        fi
        sleep 1
        attempts=$((attempts - 1))
      done

      # Let services settle before suspending
      sleep 5

      # Wait for Sablier daemon to be healthy
      attempts=30
      while [ "$attempts" -gt 0 ]; do
        if curl -sf http://127.0.0.1:10000/health | grep -q "OK"; then
          break
        fi
        sleep 1
        attempts=$((attempts - 1))
      done

      for unit in ${lib.concatStringsSep " " targetUnits}; do
        if systemctl is-active --quiet "$unit"; then
          echo "Suspending Sablier service: $unit"
          systemctl stop "$unit" || true
        fi
      done
    '';
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
      }
    ];

    environment.systemPackages = [
      sablierSuspendScript
    ];
  };
}
