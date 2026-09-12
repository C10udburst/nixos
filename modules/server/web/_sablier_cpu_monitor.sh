#!/usr/bin/env bash
set -euo pipefail

CPU_THRESHOLD="${CPU_THRESHOLD:-5}"
SESSION_DURATION="${SESSION_DURATION:-15m}"
SABLIER_URL="${SABLIER_URL:-http://127.0.0.1:10000}"

if [ "$#" -eq 0 ]; then
  echo "No units specified to monitor."
  exit 0
fi

units=("$@")
declare -A prev_cpu
declare -A prev_time

while true; do
  now=$(date +%s%N)
  for unit in "${units[@]}"; do
    state=$(systemctl is-active "$unit" 2>/dev/null || true)
    if [ "$state" = "active" ]; then
      cpu_nsec=$(systemctl show "$unit" -p CPUUsageNSec --value 2>/dev/null || echo 0)
      if [ -n "${prev_cpu[$unit]:-}" ] && [ -n "${prev_time[$unit]:-}" ]; then
        d_cpu=$((cpu_nsec - prev_cpu[$unit]))
        d_time=$((now - prev_time[$unit]))
        if [ "$d_time" -gt 0 ]; then
          pct=$(( (d_cpu * 100) / d_time ))
          if [ "$pct" -ge "$CPU_THRESHOLD" ]; then
            curl -s "${SABLIER_URL}/api/strategies/poke?names=$unit&session_duration=${SESSION_DURATION}" >/dev/null 2>&1 || true
          fi
        fi
      fi
      prev_cpu[$unit]=$cpu_nsec
      prev_time[$unit]=$now
    else
      unset "prev_cpu[$unit]" 2>/dev/null || true
      unset "prev_time[$unit]" 2>/dev/null || true
    fi
  done
  sleep 30
done
