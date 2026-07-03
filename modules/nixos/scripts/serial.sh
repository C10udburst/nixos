#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: $(basename "$0") <device> <baudrate>"
elif [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
  stty -F "$1" "$2"
  screen sh -c "cat '$1' & cat > '$1'"
else
  echo "Please run \"$(basename "$0") --help\""
  exit 1
fi
