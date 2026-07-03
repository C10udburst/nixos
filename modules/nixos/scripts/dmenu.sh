#!/usr/bin/env bash
# dmenu compatibility wrapper redirecting to noctalia-dmenu

PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) PROMPT="$2"; shift 2 ;;
        -i|-b|-f) shift ;; # Ignore case-insensitive, bottom, fast flags
        -fn|-nb|-nf|-sb|-sf|-l) shift 2 ;; # Ignore styling flags
        *) shift ;;
    esac
done

exec noctalia-dmenu ${PROMPT:+-p "$PROMPT"}
