#!/usr/bin/env bash
# weylus-screen: Setup Weylus with auto-fullscreen on client touch/click and ADB reverse forwarding.
set -euo pipefail

WIDTH="${1:-1920}"
HEIGHT="${2:-1080}"
PORT="${3:-1701}"

echo "=== Weylus Screen Setup ==="
echo "Target resolution: ${WIDTH}x${HEIGHT}"

# 1. Create custom index.html that automatically triggers fullscreen on first user touch/click
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

# 2. Check for ADB and connected devices
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
