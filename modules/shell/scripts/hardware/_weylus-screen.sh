#!/usr/bin/env bash
# weylus-screen: Setup PipeWire screen selection for Weylus without interactive rofi/dmenu,
# inject auto-fullscreen on client touch/click, and setup ADB reverse forwarding.
set -euo pipefail

WIDTH="${1:-1920}"
HEIGHT="${2:-1080}"
PORT="${3:-1701}"

echo "=== Weylus Screen Setup ==="
echo "Target resolution: ${WIDTH}x${HEIGHT}"

# 1. Determine which display to capture
SELECTED_OUTPUT=""
if command -v wlr-randr >/dev/null 2>&1; then
    OUTPUTS=$(wlr-randr --json 2>/dev/null | grep -o '"name": "[^"]*"' | tr -d '"' | awk '{print $2}' || true)
    if [ -n "$OUTPUTS" ]; then
        SELECTED_OUTPUT=$(echo "$OUTPUTS" | grep -v 'eDP-1' | head -n1 || true)
        if [ -z "$SELECTED_OUTPUT" ]; then
            SELECTED_OUTPUT=$(echo "$OUTPUTS" | head -n1)
        fi
    fi
fi

if [ -z "$SELECTED_OUTPUT" ]; then
    SELECTED_OUTPUT="eDP-1"
fi
echo "Target display output: $SELECTED_OUTPUT"

# 2. Configure xdg-desktop-portal-wlr to select this output directly without prompting rofi/dmenu
XDPW_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal-wlr"
XDPW_DRIFTWM="$XDPW_CONF_DIR/driftwm"
XDPW_CONFIG="$XDPW_CONF_DIR/config"
DRIFTWM_BACKUP=""
CONFIG_BACKUP=""

mkdir -p "$XDPW_CONF_DIR"

if [ -f "$XDPW_DRIFTWM" ]; then
    DRIFTWM_BACKUP=$(mktemp)
    cp "$XDPW_DRIFTWM" "$DRIFTWM_BACKUP"
fi
if [ -f "$XDPW_CONFIG" ]; then
    CONFIG_BACKUP=$(mktemp)
    cp "$XDPW_CONFIG" "$CONFIG_BACKUP"
fi

cat <<INI > "$XDPW_DRIFTWM"
[screencast]
output_name=$SELECTED_OUTPUT
chooser_type=none
INI
cp "$XDPW_DRIFTWM" "$XDPW_CONFIG"

# Restart portal so it reloads the config without chooser
if systemctl --user is-active --quiet xdg-desktop-portal-wlr; then
    systemctl --user restart xdg-desktop-portal-wlr || true
fi

# 3. Create custom index.html that automatically triggers fullscreen on first user touch/click
CUSTOM_DIR=$(mktemp -d /tmp/weylus-custom-XXXXXX)
CUSTOM_INDEX="$CUSTOM_DIR/index.html"

weylus --print-index-html > "$CUSTOM_INDEX"

# Create helper JS file and insert it cleanly
cat << 'JS_EOF' > "$CUSTOM_DIR/auto-fullscreen.html"
<script>
(function() {
    function autoFS() {
        if (!document.fullscreenElement) {
            var el = document.documentElement || document.body;
            var req = el.requestFullscreen || el.webkitRequestFullscreen || el.mozRequestFullScreen || el.msRequestFullscreen;
            if (req) {
                req.call(el, { navigationUI: "hide" }).catch(function() {});
            }
        }
        window.removeEventListener("pointerdown", autoFS, true);
        window.removeEventListener("touchstart", autoFS, true);
        window.removeEventListener("click", autoFS, true);
    }
    window.addEventListener("pointerdown", autoFS, true);
    window.addEventListener("touchstart", autoFS, true);
    window.addEventListener("click", autoFS, true);
})();
</script>
</body>
JS_EOF

sed -i -e '/<\/body>/r '"$CUSTOM_DIR/auto-fullscreen.html" -e '/<\/body>/d' "$CUSTOM_INDEX"

# Track devices for cleanup
FORWARDED_DEVICES=()

cleanup() {
    echo ""
    echo "Cleaning up..."
    # Restore portal configuration
    if [ -n "$DRIFTWM_BACKUP" ] && [ -f "$DRIFTWM_BACKUP" ]; then
        mv "$DRIFTWM_BACKUP" "$XDPW_DRIFTWM"
    else
        rm -f "$XDPW_DRIFTWM"
    fi
    if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
        mv "$CONFIG_BACKUP" "$XDPW_CONFIG"
    else
        rm -f "$XDPW_CONFIG"
    fi

    # Restart portal to restore standard configuration
    if systemctl --user is-active --quiet xdg-desktop-portal-wlr; then
        systemctl --user restart xdg-desktop-portal-wlr || true
    fi

    # Clean temporary custom web directory
    rm -rf "$CUSTOM_DIR"

    # Close browser window and remove ADB reverse port forwards
    for dev in "${FORWARDED_DEVICES[@]}"; do
        echo "Closing browser window on $dev..."
        adb -s "$dev" shell am force-stop com.android.chrome 2>/dev/null || true
        adb -s "$dev" shell am force-stop org.chromium.chrome 2>/dev/null || true
        echo "Removing reverse tcp:$PORT on $dev..."
        adb -s "$dev" reverse --remove "tcp:$PORT" 2>/dev/null || true
    done
}

trap cleanup EXIT INT TERM

# 4. Check for ADB and connected devices
launch_adb() {
    local port="$1"
    sleep 1

    if ! command -v adb >/dev/null 2>&1; then
        return 0
    fi

    local devices
    devices=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
    if [ -z "$devices" ]; then
        echo "No authorized ADB devices detected."
        return 0
    fi

    for dev in $devices; do
        echo "Found ADB device: $dev. Setting up reverse port forwarding tcp:$port -> tcp:$port..."
        if adb -s "$dev" reverse "tcp:$port" "tcp:$port" 2>/dev/null; then
            FORWARDED_DEVICES+=("$dev")
        fi

        local url="http://127.0.0.1:$port"
        echo "Opening $url in browser on device $dev..."
        if adb -s "$dev" shell "pm path com.android.chrome" 2>/dev/null | grep -q "package:"; then
            adb -s "$dev" shell am start -n com.android.chrome/com.google.android.apps.chrome.Main \
                -a android.intent.action.VIEW \
                -d "$url" \
                --ez "kiosk" true \
                --ez "fullscreen" true >/dev/null 2>&1 || true
        else
            adb -s "$dev" shell am start -a android.intent.action.VIEW -d "$url" >/dev/null 2>&1 || true
        fi
    done
}

launch_adb "$PORT" &

echo ""
echo "Starting Weylus with PipeWire/Wayland support (use Ctrl+C to stop)..."
weylus --auto-start --wayland-support --custom-index-html "$CUSTOM_INDEX" --web-port "$PORT" "$@" &
WEYLUS_PID=$!

wait "$WEYLUS_PID" 2>/dev/null || true
