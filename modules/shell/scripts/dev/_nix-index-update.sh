#!/usr/bin/env bash
#
# Fetch the latest prebuilt nix-index from nix-community/nix-index-database releases.
set -euo pipefail

arch="$(uname -m)"
[ "$arch" = "arm64" ] && arch="aarch64"
system="$arch-$(uname -s | tr '[:upper:]' '[:lower:]')"

cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/nix-index"

url="$(curl -fsSL https://api.github.com/repos/nix-community/nix-index-database/releases/latest |
  jq -r --arg name "index-$system" '.assets[] | select(.name == $name) | .browser_download_url')"

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: no index asset for $system in the latest nix-index-database release." >&2
  exit 1
fi

mkdir -p "$cacheDir"
curl -fL --progress-bar "$url" -o "$cacheDir/files.tmp"
mv "$cacheDir/files.tmp" "$cacheDir/files"

echo "nix-index updated for $system:"
echo "  $url"
