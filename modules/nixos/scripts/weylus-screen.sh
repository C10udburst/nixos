#!/usr/bin/env bash
# weylus-screen: Setup virtual/headless display or prepare secondary output for Weylus,
# and if an ADB device is connected, forward port and launch browser in fullscreen.
set -euo pipefail

WIDTH="${1:-1920}"
HEIGHT="${2:-1080}"
PORT="${3:-1701}"

echo "=== Weylus Screen Setup ==="
echo "Target resolution: ${WIDTH}x${HEIGHT}"

# 1. Check if VKMS DRM device is available
if [ -e /sys/module/vkms ]; then
    echo "VKMS (Virtual Kernel Mode Setting) module is loaded."
else
    echo "VKMS is not loaded. If root/sudo is available, trying 'sudo modprobe vkms'..."
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo modprobe vkms enable_cursor=1 enable_overlay=1 enable_writeback=1 || true
    fi
fi

# 2. Check wlr-randr outputs
if command -v wlr-randr >/dev/null 2>&1; then
    echo "Current Wayland (wlr-randr) outputs:"
    wlr-randr || true

    # Check for disconnected DRM connectors that can be configured or virtual heads
    VIRT_OUT=$(wlr-randr --json 2>/dev/null | grep -o '"name": "[^"]*"' | tr -d '"' | awk '{print $2}' | grep -E 'HEADLESS|Virtual|VKMS|DP|HDMI' | tail -n1 || true)
    if [ -n "$VIRT_OUT" ]; then
        echo "Configuring display output: $VIRT_OUT"
        wlr-randr --output "$VIRT_OUT" --custom-mode "${WIDTH}x${HEIGHT}@60Hz" --on || true
    fi
fi

# 3. Check for ADB and connected devices
launch_adb() {
    local port="$1"
    # Wait for Weylus server to start listening
    sleep 1

    if ! command -v adb >/dev/null 2>&1; then
        return 0
    fi

    # Retrieve attached devices in 'device' state
    local devices
    devices=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
    if [ -z "$devices" ]; then
        echo "No authorized ADB devices detected."
        return 0
    fi

    for dev in $devices; do
        echo "Found ADB device: $dev. Setting up reverse port forwarding tcp:$port -> tcp:$port..."
        adb -s "$dev" reverse "tcp:$port" "tcp:$port" 2>/dev/null || true

        local url="http://127.0.0.1:$port"
        echo "Opening $url in browser on device $dev..."
        # Try Chrome first with kiosk/fullscreen flags, fallback to default VIEW intent
        if adb -s "$dev" shell "pm path com.android.chrome" 2>/dev/null | grep -q "package:"; then
            adb -s "$dev" shell am start -n com.android.chrome/com.google.android.apps.chrome.Main \
                -a android.intent.action.VIEW \
                -d "$url" \
                --ez "kiosk" true \
                --ez "fullscreen" true >/dev/null 2>&1 || true
        else
            adb -s "$dev" shell am start -a android.intent.action.VIEW -d "$url" >/dev/null 2>&1 || true
        fi

        # Send fullscreen toggle key event (F11 / KEYCODE_WINDOW) in case browser supports it
        sleep 1
        adb -s "$dev" shell input keyevent 171 2>/dev/null || true # KEYCODE_WINDOW (toggle fullscreen on Android)
    done
}

launch_adb "$PORT" &

echo ""
echo "Starting Weylus..."
exec weylus --auto-start --web-port "$PORT" "$@"
