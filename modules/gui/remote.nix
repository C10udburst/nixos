{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.gui.remote;

  remoteHosts = lib.filterAttrs (host: _: host != config.networking.hostName) cfg.hosts;

  hostCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (host: command: ''
      "${host}")
        CMD="${command}"
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

    if [ "$#" -gt 1 ]; then
      shift
      CMD="$*"
    else
      case "$HOST" in
        ${hostCases}
        *)
          echo "No default command configured for host '$HOST'." >&2
          echo "Usage: remote-gui $HOST <command...>" >&2
          exit 1
          ;;
      esac
    fi

    LOCAL_PULSE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
    if [ ! -S "$LOCAL_PULSE" ] && [ -S "/run/user/$(id -u)/pulse/native" ]; then
        LOCAL_PULSE="/run/user/$(id -u)/pulse/native"
    fi

    REMOTE_PULSE="/tmp/pulse-remote-''${USER}.sock"

    if [ -S "$LOCAL_PULSE" ]; then
        exec ${pkgs.waypipe}/bin/waypipe ssh \
            -o StreamLocalBindUnlink=yes \
            -R "''${REMOTE_PULSE}:''${LOCAL_PULSE}" \
            "$HOST" \
            env PULSE_SERVER="unix:''${REMOTE_PULSE}" $CMD
    else
        exec ${pkgs.waypipe}/bin/waypipe ssh "$HOST" $CMD
    fi
  '';

  desktopEntries =
    lib.mapAttrsToList (
      host: command:
        pkgs.makeDesktopItem {
          name = "remote-gui-${host}";
          desktopName = "Remote GUI (${host})";
          exec = "${remoteGui}/bin/remote-gui ${host}";
          icon =
            if lib.hasInfix "plasma" command
            then "kde"
            else "preferences-desktop-remote-desktop";
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
      type = lib.types.attrsOf lib.types.str;
      default = {
        cloudburst-desktop = "plasmawindowed org.kde.plasma.kickoff";
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
