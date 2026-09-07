#!/usr/bin/env bash
# auto-rotate: Accelerometer auto-rotation script for Wayland (wlr-randr)

set -euo pipefail

# Wait for Wayland display compositor (wlr-randr) to respond
while ! wlr-randr >/dev/null 2>&1; do
  sleep 0.5
done

rotate() {
  local transform="$1"

  # Rotate Wayland display outputs (compositor transforms mapped touchscreen input automatically)
  for output in $(wlr-randr | grep '^[^ ]' | awk '{print $1}'); do
    wlr-randr --output "$output" --transform "$transform" || true
  done
}

# Initial rotation on boot (default to 270 degrees)
rotate "270"

exec monitor-sensor --accel | while read -r line; do
  case "$line" in
    *"orientation changed: normal"*)
      rotate "normal"
      ;;
    *"orientation changed: bottom-up"*)
      rotate "180"
      ;;
    *"orientation changed: left-up"*)
      rotate "90"
      ;;
    *"orientation changed: right-up"*)
      rotate "270"
      ;;
  esac
done
