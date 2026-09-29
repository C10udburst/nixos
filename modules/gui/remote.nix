{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.remote;

  remoteHosts = lib.filterAttrs (host: _: host != config.networking.hostName) cfg.hosts;

  hostCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (host: hostCfg: ''
      "${host}")
        CMD="${hostCfg.cmd}"
        USE_GPU="${
        if hostCfg.gpu
        then "1"
        else "0"
      }"
        ;;
    '')
    cfg.hosts
  );

  remoteGui = pkgs.writeShellScriptBin "remote-gui" ''
    set -euo pipefail

    HOST="''${1:-}"
    if [ -z "$HOST" ]; then
      echo "Usage: remote-gui <host> [command...]" >&2
      echo "Configured hosts: ${lib.concatStringsSep ", " (builtins.attrNames cfg.hosts)}" >&2
      exit 1
    fi

    USE_GPU="0"
    case "$HOST" in
      ${hostCases}
      *)
        if [ "$#" -le 1 ]; then
          echo "No default command configured for host '$HOST'." >&2
          echo "Usage: remote-gui $HOST <command...>" >&2
          exit 1
        fi
        ;;
    esac

    if [ "$#" -gt 1 ]; then
      shift
      CMD="$*"
    fi

    WAYPIPE_FLAGS=()
    if [ "$USE_GPU" != "1" ]; then
      WAYPIPE_FLAGS+=("--no-gpu")
    fi

    LOCAL_PULSE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
    if [ ! -S "$LOCAL_PULSE" ] && [ -S "/run/user/$(id -u)/pulse/native" ]; then
        LOCAL_PULSE="/run/user/$(id -u)/pulse/native"
    fi

    REMOTE_PULSE="/tmp/pulse-remote-''${USER}.sock"

    if [ -S "$LOCAL_PULSE" ]; then
        exec ${pkgs.waypipe}/bin/waypipe "''${WAYPIPE_FLAGS[@]}" ssh \
            -o StreamLocalBindUnlink=yes \
            -R "''${REMOTE_PULSE}:''${LOCAL_PULSE}" \
            "$HOST" \
            env PULSE_SERVER="unix:''${REMOTE_PULSE}" $CMD
    else
        exec ${pkgs.waypipe}/bin/waypipe "''${WAYPIPE_FLAGS[@]}" ssh "$HOST" $CMD
    fi
  '';

  desktopEntries =
    lib.mapAttrsToList (
      host: hostCfg:
        pkgs.makeDesktopItem {
          name = "remote-gui-${host}";
          desktopName = "${host} (Remote)";
          exec = "${remoteGui}/bin/remote-gui ${host}";
          icon = hostCfg.icon;
          terminal = false;
        }
    )
    remoteHosts;
in {
  options.features.gui.remote = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.features.gui.enable && true;
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            cmd = lib.mkOption {
              type = lib.types.str;
              default = "plasmawindowed org.kde.plasma.kickoff";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = "kde";
            };
            gpu = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
      );
      default = {
        cloudburst-desktop = {
          cmd = "plasmawindowed org.kde.plasma.kickoff";
          icon = "kde";
          gpu = true;
        };
        cloudburst-laptop = {
          cmd = "plasmawindowed org.kde.plasma.kickoff";
          icon = "kde";
          gpu = false;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [
        remoteGui
        pkgs.waypipe
      ]
      ++ desktopEntries;
  };
}
