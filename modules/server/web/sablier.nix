{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.features.server.web.sablier;
  webCfg = config.features.server.web;
  uniqueUnits = lib.unique cfg._suspendedUnits;
in {
  options.features.server.web.sablier = lib.mkOption {
    type = lib.types.coercedTo lib.types.bool (b: {enable = b;}) (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = webCfg.enable && true;
          };
          cpuThreshold = lib.mkOption {
            type = lib.types.int;
            default = 5;
          };
          sessionDuration = lib.mkOption {
            type = lib.types.str;
            default = "15m";
          };
          _suspendedUnits = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            internal = true;
          };
        };
      }
    );
    default = {};
  };

  config = lib.mkMerge [
    {
      flake-file.inputs = {
        sablier-bin = {
          url = "https://github.com/sablierapp/sablier/releases/download/v1.18.0/sablier-1.18.0-linux-amd64.tar.gz";
          flake = false;
        };
      };
    }
    (lib.mkIf cfg.enable (let
      sablierPkg = pkgs.runCommand "sablier" {} ''
        install -Dm755 ${inputs.sablier-bin}/sablier $out/bin/sablier
      '';
    in {
      systemd.services.sablier = {
        description = "Sablier scale-to-zero server";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          ExecStart = ''
            ${sablierPkg}/bin/sablier start \
              --server.port=10000 \
              --provider.name=systemd \
              --storage.file=/var/lib/sablier/state.json
          '';
          Restart = "on-failure";
          RestartSec = "5s";
          StateDirectory = "sablier";
        };
      };

      systemd.services.sablier-cpu-monitor = lib.mkIf (uniqueUnits != []) {
        description = "Sablier CPU activity monitor for suspended services";
        wantedBy = ["multi-user.target"];
        after = ["sablier.service"];
        path = [
          pkgs.systemd
          pkgs.curl
          pkgs.coreutils
          pkgs.bash
        ];
        environment = {
          CPU_THRESHOLD = toString cfg.cpuThreshold;
          SESSION_DURATION = cfg.sessionDuration;
          SABLIER_URL = "http://127.0.0.1:10000";
        };
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5s";
          ExecStart = "${./_sablier_cpu_monitor.sh} ${lib.concatStringsSep " " uniqueUnits}";
        };
      };
    }))
  ];
}
