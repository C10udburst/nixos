#!/usr/bin/env bash
# wmenu compatibility wrapper redirecting to noctalia-dmenu

PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) PROMPT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

exec noctalia-dmenu ${PROMPT:+-p "$PROMPT"}
