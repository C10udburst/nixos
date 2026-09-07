#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <file>" >&2
  exit 1
fi

mimeType=""

if [ -f "$1" ]; then
  mimeType=$(file -b --mime-type "$1")
  #                └─ do not prepend the filename to the output

  if [[ $mimeType == text/* ]]; then
    mimeType="$mimeType;charset=utf-8"
  fi

  printf "data:%s;base64,%s" \
    "$mimeType" \
    "$(openssl base64 -in "$1" | tr -d "\n")"
else
  echo "$1 is not a file." >&2
  exit 1
fi
