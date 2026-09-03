#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-cloudburst-desktop}"

LOCAL_PULSE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
if [ ! -S "$LOCAL_PULSE" ] && [ -S "/run/user/$(id -u)/pulse/native" ]; then
    LOCAL_PULSE="/run/user/$(id -u)/pulse/native"
fi

REMOTE_PULSE="/tmp/pulse-remote-${USER}.sock"

if [ -S "$LOCAL_PULSE" ]; then
    exec waypipe ssh \
        -o StreamLocalBindUnlink=yes \
        -R "${REMOTE_PULSE}:${LOCAL_PULSE}" \
        "$HOST" \
        PULSE_SERVER="unix:${REMOTE_PULSE}" plasmawindowed org.kde.plasma.kickoff
else
    exec waypipe ssh "$HOST" plasmawindowed org.kde.plasma.kickoff
fi
