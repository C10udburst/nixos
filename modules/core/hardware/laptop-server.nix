{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.core.hardware;

  laptopServerLid = pkgs.writeShellScriptBin "laptop-server-lid" ''
    set -eu

    STATE_DIR="/run/laptop-server"
    BACKLIGHT_SAVED_DIR="$STATE_DIR/backlight"
    LEDS_SAVED_DIR="$STATE_DIR/leds"

    mkdir -p "$BACKLIGHT_SAVED_DIR" "$LEDS_SAVED_DIR"

    is_lid_closed() {
      local state
      state="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed 2>/dev/null || true)"
      case "$state" in
        "b true") return 0 ;;
        "b false") return 1 ;;
      esac

      for f in /proc/acpi/button/lid/*/state; do
        if [ -f "$f" ]; then
          if grep -qi "closed" "$f"; then
            return 0
          fi
          if grep -qi "open" "$f"; then
            return 1
          fi
        fi
      done

      return 1
    }

    turn_off() {
      for dev in /sys/class/backlight/*; do
        if [ -d "$dev" ]; then
          name="$(basename "$dev")"
          save_file="$BACKLIGHT_SAVED_DIR/$name"

          if [ -r "$dev/brightness" ]; then
            cur="$(cat "$dev/brightness" 2>/dev/null || true)"
            case "$cur" in
              *[!0-9]*) cur=0 ;;
            esac
            if [ -z "$cur" ]; then cur=0; fi

            if [ "$cur" -gt 0 ] && [ ! -f "$save_file" ]; then
              echo "$cur" > "$save_file"
            fi
          fi

          if [ -w "$dev/bl_power" ]; then
            echo 4 > "$dev/bl_power" 2>/dev/null || true
          fi

          if [ -w "$dev/brightness" ]; then
            echo 0 > "$dev/brightness" 2>/dev/null || true
          fi
        fi
      done

      for dev in /sys/class/leds/*kbd_backlight* /sys/class/leds/*::kbd_backlight* /sys/class/leds/*kbd_rgb* /sys/class/leds/*keyboard_backlight*; do
        if [ -d "$dev" ] && [ -w "$dev/brightness" ]; then
          name="$(basename "$dev")"
          save_file="$LEDS_SAVED_DIR/$name"

          if [ -r "$dev/brightness" ]; then
            cur="$(cat "$dev/brightness" 2>/dev/null || true)"
            case "$cur" in
              *[!0-9]*) cur=0 ;;
            esac
            if [ -z "$cur" ]; then cur=0; fi

            if [ "$cur" -gt 0 ] && [ ! -f "$save_file" ]; then
              echo "$cur" > "$save_file"
            fi
          fi

          echo 0 > "$dev/brightness" 2>/dev/null || true
        fi
      done

      if [ -w /proc/acpi/ibm/kbdlight ]; then
        echo 0 > /proc/acpi/ibm/kbdlight 2>/dev/null || true
      fi
    }

    turn_on() {
      for dev in /sys/class/backlight/*; do
        if [ -d "$dev" ]; then
          name="$(basename "$dev")"
          save_file="$BACKLIGHT_SAVED_DIR/$name"

          if [ -w "$dev/bl_power" ]; then
            echo 0 > "$dev/bl_power" 2>/dev/null || true
          fi

          if [ -f "$save_file" ]; then
            val="$(cat "$save_file" 2>/dev/null || true)"
            case "$val" in
              *[!0-9]*) val=0 ;;
            esac
            if [ -z "$val" ]; then val=0; fi

            if [ "$val" -gt 0 ] && [ -w "$dev/brightness" ]; then
              echo "$val" > "$dev/brightness" 2>/dev/null || true
            fi
            rm -f "$save_file"
          else
            if [ -r "$dev/max_brightness" ] && [ -w "$dev/brightness" ]; then
              cur="$(cat "$dev/brightness" 2>/dev/null || true)"
              case "$cur" in
                *[!0-9]*) cur=0 ;;
              esac
              if [ -z "$cur" ]; then cur=0; fi

              if [ "$cur" -eq 0 ]; then
                max="$(cat "$dev/max_brightness" 2>/dev/null || true)"
                case "$max" in
                  *[!0-9]*) max=0 ;;
                esac
                if [ -z "$max" ]; then max=0; fi

                if [ "$max" -gt 0 ]; then
                  echo "$(( max / 2 ))" > "$dev/brightness" 2>/dev/null || true
                fi
              fi
            fi
          fi
        fi
      done

      for dev in /sys/class/leds/*kbd_backlight* /sys/class/leds/*::kbd_backlight* /sys/class/leds/*kbd_rgb* /sys/class/leds/*keyboard_backlight*; do
        if [ -d "$dev" ] && [ -w "$dev/brightness" ]; then
          name="$(basename "$dev")"
          save_file="$LEDS_SAVED_DIR/$name"

          if [ -f "$save_file" ]; then
            val="$(cat "$save_file" 2>/dev/null || true)"
            case "$val" in
              *[!0-9]*) val="" ;;
            esac
            if [ -n "$val" ]; then
              echo "$val" > "$dev/brightness" 2>/dev/null || true
            fi
            rm -f "$save_file"
          fi
        fi
      done

      if [ -w /proc/acpi/ibm/kbdlight ]; then
        echo 2 > /proc/acpi/ibm/kbdlight 2>/dev/null || true
      fi
    }

    last_state=""

    apply_state() {
      local current_state="open"
      if is_lid_closed; then
        current_state="closed"
      fi

      if [ "$current_state" = "$last_state" ]; then
        return 0
      fi

      if [ "$current_state" = "closed" ]; then
        turn_off
      else
        turn_on
      fi
      last_state="$current_state"
    }

    case "''${1:-daemon}" in
      status)
        if is_lid_closed; then
          echo "Lid state: closed"
        else
          echo "Lid state: open"
        fi
        exit 0
        ;;
      close|off)
        turn_off
        exit 0
        ;;
      open|on)
        turn_on
        exit 0
        ;;
      daemon)
        apply_state
        while true; do
          busctl wait org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.DBus.Properties PropertiesChanged >/dev/null 2>&1 || sleep 1
          sleep 0.1
          apply_state
        done
        ;;
      *)
        echo "Usage: laptop-server-lid [daemon|status|close|open]"
        exit 1
        ;;
    esac
  '';
in {
  options.features.core.hardware.laptop-server = lib.mkOption {
    type = lib.types.bool;
    default = config.features.core.hardware.enable && false;
  };

  config = lib.mkIf cfg.laptop-server {
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      LidSwitchIgnoreInhibited = "yes";
    };

    boot.kernelParams = ["consoleblank=60"];

    systemd.services.laptop-server-lid = {
      description = "Manage laptop screen and keyboard lights on lid state change";
      wantedBy = ["multi-user.target"];
      after = ["systemd-logind.service"];
      wants = ["systemd-logind.service"];
      path = [
        pkgs.systemd
        pkgs.coreutils
        pkgs.gnugrep
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${laptopServerLid}/bin/laptop-server-lid daemon";
        Restart = "always";
        RestartSec = "2s";
      };
    };

    environment.systemPackages = [
      laptopServerLid
    ];
  };
}
