#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from urllib.parse import parse_qs

systemctl = os.environ.get("SYSTEMCTL", "systemctl")
services_env = os.environ.get("SYSTEMD_SERVICES", "[]")

try:
    configured = json.loads(services_env)
    if not isinstance(configured, list):
        configured = []
except Exception:
    configured = []

method = os.environ.get("REQUEST_METHOD", "GET")

# Handle CORS preflight
if method == "OPTIONS":
    print(
        "Status: 204 No Content\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: GET, OPTIONS\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "Cache-Control: no-cache, no-store, must-revalidate\r\n\r\n",
        end="",
    )
    sys.exit(0)

# Extract requested path or query
raw_path = os.environ.get("PATH_INFO") or os.environ.get("REQUEST_URI", "").split("?")[0]
path = raw_path.strip("/")

for prefix in ("systemd.json", "systemd.cgi", "systemd.py", "systemd"):
    if path == prefix:
        path = ""
        break
    elif path.startswith(prefix + "/"):
        path = path[len(prefix) + 1 :].strip("/")
        break

if path.endswith(".json"):
    path = path[:-5].strip("/")

query_string = os.environ.get("QUERY_STRING", "")
qs = parse_qs(query_string)

single_mode = False
requested = []

if path and path not in ("status", "all"):
    requested = [path]
    single_mode = True
elif query_string:
    if "single" in qs and qs["single"][0].lower() in ("1", "true", "yes"):
        single_mode = True
    for key in ("service", "services", "unit", "units", "name"):
        if key in qs:
            for val in qs[key]:
                requested.extend([s.strip() for s in val.split(",") if s.strip()])
            break

if not requested:
    requested = list(configured)

safe_re = re.compile(r"^[a-zA-Z0-9_\-\.@]+$")
requested = [s for s in requested if safe_re.match(s)]

norm = lambda s: s[:-8] if s.endswith(".service") else s

if configured:
    allowed = {norm(s) for s in configured}
    resolved = [norm(s) for s in requested if norm(s) in allowed]

    if not resolved and requested:
        print(
            "Status: 404 Not Found\r\n"
            "Content-Type: application/json; charset=utf-8\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Cache-Control: no-cache, no-store, must-revalidate\r\n\r\n",
            end="",
        )
        print(json.dumps({"error": "Service not found or not in watched list"}))
        sys.exit(0)
    requested = resolved

units = [f"{norm(s)}.service" for s in requested]

result_list = []

if units:
    cmd = [
        systemctl,
        "show",
        *units,
        "--timestamp=unix",
        "-p",
        "Id",
        "-p",
        "Description",
        "-p",
        "LoadState",
        "-p",
        "ActiveState",
        "-p",
        "SubState",
        "-p",
        "StateChangeTimestamp",
        "-p",
        "MemoryCurrent",
        "-p",
        "CPUUsageNSec",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        blocks = [b.strip() for b in proc.stdout.split("\n\n") if b.strip()]
    except Exception:
        blocks = []

    for b in blocks:
        props = dict(line.split("=", 1) for line in b.splitlines() if "=" in line)
        load_state = props.get("LoadState", "not-found")
        if not single_mode and load_state == "not-found":
            continue

        unit_id = props.get("Id", "")
        base_name = norm(unit_id)
        active_state = props.get("ActiveState", "unknown")
        sub_state = props.get("SubState", "unknown")
        status = sub_state if active_state == "active" else active_state

        raw_ts = props.get("StateChangeTimestamp", "")
        ts_str = None
        if raw_ts.startswith("@"):
            try:
                sec = int(raw_ts[1:])
                if sec > 0:
                    ts_str = datetime.fromtimestamp(sec, timezone.utc).isoformat()
            except ValueError:
                pass

        raw_mem = props.get("MemoryCurrent", "")
        mem_val = None
        if raw_mem and raw_mem != "[not set]":
            try:
                val = int(raw_mem)
                if val != 18446744073709551615:
                    mem_val = val
            except ValueError:
                pass

        raw_cpu = props.get("CPUUsageNSec", "")
        cpu_val = None
        if raw_cpu and raw_cpu != "[not set]":
            try:
                val = int(raw_cpu)
                if val != 18446744073709551615:
                    cpu_val = val
            except ValueError:
                pass

        result_list.append(
            {
                "name": base_name,
                "description": props.get("Description", ""),
                "status": status,
                "timestamp": ts_str,
                "memory": mem_val,
                "cpu": cpu_val,
            }
        )

print(
    "Status: 200 OK\r\n"
    "Content-Type: application/json; charset=utf-8\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "Access-Control-Allow-Methods: GET, OPTIONS\r\n"
    "Access-Control-Allow-Headers: Content-Type\r\n"
    "Cache-Control: no-cache, no-store, must-revalidate\r\n\r\n",
    end="",
)

if single_mode and len(result_list) == 1:
    print(json.dumps(result_list[0], indent=2))
else:
    print(json.dumps(result_list, indent=2))
