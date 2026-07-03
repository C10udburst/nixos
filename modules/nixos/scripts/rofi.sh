#!/usr/bin/env bash
# rofi compatibility wrapper routing to noctalia-dmenu or native launcher

PROMPT=""
DMENU_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -dmenu) DMENU_MODE=true; shift ;;
        -p|-placeholder|-mesg) PROMPT="$2"; shift 2 ;;
        -show) shift 2 ;;
        # Ignore styling and other flags
        -theme|-font|-i|-markup-rows|-no-lazy-grab|-show-icons|-sidebar-mode|-theme-str) shift 2 ;;
        *) shift ;;
    esac
done

if [[ "$DMENU_MODE" == true ]]; then
    exec noctalia-dmenu ${PROMPT:+-p "$PROMPT"}
else
    # Default to toggling the native app launcher
    exec noctalia-shell ipc call launcher toggle
fi
