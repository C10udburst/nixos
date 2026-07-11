#!/usr/bin/env bash

# Wait for the ADB device to be connected
echo "[1/3] Waiting for ADB device..."
adb wait-for-device

# If no app package name is provided as an argument, open Rofi to select a package
if [ -z "${1:-}" ]; then
    echo "No package specified. Opening Rofi package selector..."
    # adb shell pm list packages may return carriage returns, so we strip them using tr
    APP_PACKAGE=$(adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort | rofi -dmenu -p "Select Android App:")
    if [ -z "$APP_PACKAGE" ]; then
        echo "No app selected or Rofi cancelled. Exiting."
        exit 0
    fi
else
    APP_PACKAGE="$1"
fi

echo "[2/3] Starting virtual display and app: $APP_PACKAGE..."
# scrcpy will automatically create a display, launch the app within it,
# and destroy it along with the app process upon closing the window.
scrcpy --new-display=720x1280/320 --flex-display --no-vd-system-decorations --start-app="$APP_PACKAGE" --keep-active

echo "[3/3] scrcpy window closed. Display removed, app stopped."
