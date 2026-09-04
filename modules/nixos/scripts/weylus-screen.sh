#!/usr/bin/env bash
# weylus-screen: Setup virtual/headless display or prepare secondary output for Weylus
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
        sudo modprobe vkms enable_cursor=1 || true
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

echo ""
echo "Starting Weylus..."
exec weylus --auto-start --web-port "$PORT" "$@"
