#!/usr/bin/env bash
#
# fix-opt-permissions.sh: Fix ownership, permissions, and clean stale rootless Podman
# storage on brix0 after rsync from another machine.
#
# Run with sudo on brix0:
#   sudo ./fix-opt-permissions.sh
#
set -eo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This script must be run as root (use sudo)."
  exit 1
fi

echo "🛑 Stopping all running Podman services..."
systemctl stop 'podman-*' 2>/dev/null || true

echo "🧹 Cleaning stale rootless Podman storage copied from another host..."
# Rootless Podman uses subuid/subgid ranges that differ per-host.
# Rsynced .local/share/containers directories contain layer mounts owned by foreign
# subuids, which causes the 'failed to mount overlay for metacopy check: permission denied' error.
# The container data (databases, configs) is in the root of each /opt/<app> folder and is NOT deleted.
for d in /opt/*/.local/share/containers /opt/*/.config/containers; do
  if [[ -d "$d" ]]; then
    echo "   Removing stale Podman storage: $d"
    rm -rf "$d"
  fi
done

echo "🔧 Setting base /opt ownership and permissions..."
chown root:web /opt 2>/dev/null || chown root:root /opt
chmod 2775 /opt

# Helper to safely chown/chmod a service directory if the user exists
fix_dir() {
  local dir="$1"
  local user="$2"
  local group="$3"
  local dir_mode="$4"

  if [[ -d "$dir" ]]; then
    if id "$user" &>/dev/null; then
      echo "   Configuring $dir -> $user:$group ($dir_mode)..."
      chown -R "$user:$group" "$dir"
      # Base permissions: read/execute for group, restricted for others
      chmod -R u=rwX,g=rX,o= "$dir"
      # Top-level directory mode with setgid
      chmod "$dir_mode" "$dir"
    else
      echo "   ⚠️ User '$user' not found, skipping $dir"
    fi
  fi
}

echo "👤 Setting per-user ownership and permissions in /opt..."

# General shared storage
fix_dir "/opt/dane"          "cloudburst"    "users"         "0775"

# Web services & applications
fix_dir "/opt/wealthfolio"   "wealthfolio"   "web"           "2751"
fix_dir "/opt/vaultwarden"   "vaultwarden"   "web"           "2750"
fix_dir "/opt/transmute"     "transmute"     "web"           "2750"
fix_dir "/opt/siyuan"        "siyuan"        "web"           "2750"
fix_dir "/opt/sablier"       "root"          "web"           "2750"
fix_dir "/opt/resume"        "resume"        "web"           "2751"
fix_dir "/opt/pihole"        "pihole-ftl"    "web"           "2750" 2>/dev/null || fix_dir "/opt/pihole" "pihole" "web" "2750"
fix_dir "/opt/organizeer"    "organizeer"    "web"           "2750"
fix_dir "/opt/manyfold"      "manyfold"      "web"           "2750"
fix_dir "/opt/litellm"       "litellm"       "web"           "2750"
fix_dir "/opt/karakeep"      "karakeep"      "web"           "2750"
fix_dir "/opt/immich"        "immich"        "web"           "2750"
fix_dir "/opt/homeassistant" "homeassistant" "web"           "2755"
fix_dir "/opt/homarr"        "homarr"        "web"           "2750"
fix_dir "/opt/golink"        "golink"        "web"           "2750"
fix_dir "/opt/gitea"         "gitea"         "gitea"         "0750"
fix_dir "/opt/fetlife"       "fetlife"       "web"           "2750"
fix_dir "/opt/eightmb"       "eightmb"       "web"           "2750"
fix_dir "/opt/duplicati"     "duplicati"     "web"           "2750"

# Specific subdirectories with unique owners
if [[ -d "/opt/homeassistant/esphome" ]] && id esphome &>/dev/null; then
  fix_dir "/opt/homeassistant/esphome" "esphome" "web" "2750"
fi

echo "📋 Enforcing all declarative NixOS systemd-tmpfiles rules..."
systemd-tmpfiles --create

echo "🔄 Resetting failed systemd units and restarting Podman services..."
systemctl reset-failed 'podman-*' 2>/dev/null || true
systemctl restart 'podman-*' 2>/dev/null || true

echo -e "\n📊 Podman service status:"
systemctl list-units 'podman-*' --no-pager

echo -e "\n✅ All permissions configured successfully!"
