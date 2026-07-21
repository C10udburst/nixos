#!/usr/bin/env bash
#
# rofi — Rofi emulation wrapper script using noctalia-dmenu and driftwm
#

set -euo pipefail

SHOW_MODE=""
DMENU_MODE=false
PROMPT=""
ONLY_MATCH=false
FORMAT="plain"
FILTER=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -dmenu)
            DMENU_MODE=true
            shift
            ;;
        -show)
            if [[ $# -lt 2 ]]; then
                echo "rofi: -show option requires an argument" >&2
                exit 1
            fi
            SHOW_MODE="$2"
            shift 2
            ;;
        -p|-prompt)
            if [[ $# -lt 2 ]]; then
                echo "rofi: $1 option requires an argument" >&2
                exit 1
            fi
            PROMPT="$2"
            shift 2
            ;;
        -only-match|-no-custom)
            ONLY_MATCH=true
            shift
            ;;
        -format)
            if [[ $# -lt 2 ]]; then
                echo "rofi: -format option requires an argument" >&2
                exit 1
            fi
            if [[ "$2" == "i" || "$2" == "d" ]]; then
                FORMAT="index"
            else
                FORMAT="plain"
            fi
            shift 2
            ;;
        -filter)
            if [[ $# -lt 2 ]]; then
                echo "rofi: -filter option requires an argument" >&2
                exit 1
            fi
            FILTER="$2"
            shift 2
            ;;
        -no-lazy-grab|-show-icons)
            # Ignored options for backward compatibility
            shift
            ;;
        -theme|-theme-str)
            # Ignored option with argument
            shift 2
            ;;
        *)
            # Try to treat positional argument as show mode if not already set
            if [[ -z "$SHOW_MODE" && "$DMENU_MODE" == "false" && "$1" != -* ]]; then
                SHOW_MODE="$1"
                shift
            else
                # Ignore other unknown flags to prevent crashes in random launcher scripts
                shift
            fi
            ;;
    esac
done

if [[ "$DMENU_MODE" == "false" && -z "$SHOW_MODE" ]]; then
    SHOW_MODE="drun"
fi

if [[ "$DMENU_MODE" == "true" ]]; then
    extra_args=()
    if [[ -n "$PROMPT" ]]; then
        extra_args+=("-p" "$PROMPT")
    fi
    if [[ "$ONLY_MATCH" == "false" ]]; then
        extra_args+=("-c")
    fi
    if [[ "$FORMAT" == "index" ]]; then
        extra_args+=("-F" "index")
    else
        extra_args+=("-F" "plain")
    fi
    exec noctalia-dmenu "${extra_args[@]}"
fi

case "$SHOW_MODE" in
    drun)
        apps_list=$(python3 -c '
import os, sys, re
apps = {}
seen = set()
paths = [os.path.expanduser("~/.local/share/applications"), "/run/current-system/sw/share/applications"]
xdg = os.environ.get("XDG_DATA_DIRS", "").split(":")
for d in xdg:
    if d:
        p = os.path.join(d, "applications")
        if os.path.isdir(p):
            paths.append(p)
for p in paths:
    if not os.path.isdir(p): continue
    for root, _, files in os.walk(p):
        for file in files:
            if file.endswith(".desktop"):
                if file in seen: continue
                seen.add(file)
                try:
                    with open(os.path.join(root, file), errors="ignore") as f:
                        content = f.read()
                except: continue
                m = re.search(r"^\[Desktop Entry\](.*?)(?=\n\[|$)", content, re.DOTALL | re.MULTILINE)
                if not m: continue
                sec = m.group(1)
                if re.search(r"^NoDisplay\s*=\s*(true|1)", sec, re.MULTILINE | re.IGNORECASE): continue
                if re.search(r"^Hidden\s*=\s*(true|1)", sec, re.MULTILINE | re.IGNORECASE): continue
                nm = re.search(r"^Name\s*=\s*(.+)", sec, re.MULTILINE)
                ex = re.search(r"^Exec\s*=\s*(.+)", sec, re.MULTILINE)
                if nm and ex:
                    name = nm.group(1).strip()
                    cmd = ex.group(1).strip()
                    cmd = re.sub(r"%[fFuUdDnNkiIv]", "", cmd).strip()
                    if name not in apps:
                        apps[name] = cmd
for name, cmd in apps.items():
    print(f"{name}\t{cmd}")
')
        names=$(echo "$apps_list" | cut -f1)
        extra_args=()
        if [[ -n "$PROMPT" ]]; then
            extra_args+=("-p" "$PROMPT")
        else
            extra_args+=("-p" "drun")
        fi
        if [[ "$ONLY_MATCH" == "false" ]]; then
            extra_args+=("-c")
        fi

        selected=$(echo "$names" | noctalia-dmenu "${extra_args[@]}")
        if [[ -n "$selected" ]]; then
            exec_cmd=$(echo "$apps_list" | awk -F'\t' -v sel="$selected" '$1 == sel {print $2}')
            if [[ -n "$exec_cmd" ]]; then
                eval "$exec_cmd &"
            else
                if [[ "$ONLY_MATCH" == "false" ]]; then
                    eval "$selected &"
                fi
            fi
        fi
        ;;

    run)
        execs=$(python3 -c '
import os
execs = set()
for path in os.environ.get("PATH", "").split(":"):
    if os.path.isdir(path):
        try:
            for entry in os.scandir(path):
                if entry.is_file() and os.access(entry.path, os.X_OK):
                    execs.add(entry.name)
        except: pass
for e in sorted(execs):
    print(e)
')
        extra_args=()
        if [[ -n "$PROMPT" ]]; then
            extra_args+=("-p" "$PROMPT")
        else
            extra_args+=("-p" "run")
        fi
        if [[ "$ONLY_MATCH" == "false" ]]; then
            extra_args+=("-c")
        fi

        selected=$(echo "$execs" | noctalia-dmenu "${extra_args[@]}")
        if [[ -n "$selected" ]]; then
            eval "$selected &"
        fi
        ;;

    window)
        windows_json=$(driftwm msg state --json 2>/dev/null || echo "")
        if [[ -z "$windows_json" ]]; then
            echo "rofi: driftwm is not running or state query failed." >&2
            exit 1
        fi
        window_list=$(echo "$windows_json" | jq -r '.Ok.State.windows[] | "\(.app_id): \(.title)"' 2>/dev/null || echo "")
        if [[ -z "$window_list" ]]; then
            # No windows open, tell the user or exit
            window_list="(no windows open)"
        fi
        extra_args=()
        if [[ -n "$PROMPT" ]]; then
            extra_args+=("-p" "$PROMPT")
        else
            extra_args+=("-p" "window")
        fi

        selected=$(echo "$window_list" | noctalia-dmenu "${extra_args[@]}")
        if [[ -n "$selected" && "$selected" != "(no windows open)" ]]; then
            app_id=$(echo "$selected" | cut -d':' -f1)
            driftwm msg focus "$app_id"
        fi
        ;;

    ssh)
        hosts=$(python3 -c '
import os, re
hosts = set()
for path in [os.path.expanduser("~/.ssh/config"), "/etc/ssh/ssh_config"]:
    if os.path.exists(path):
        try:
            with open(path) as f:
                for line in f:
                    m = re.match(r"^\s*Host\s+(.+)", line, re.IGNORECASE)
                    if m:
                        for h in m.group(1).split():
                            if h and "*" not in h and "?" not in h:
                                hosts.add(h)
        except: pass
kh = os.path.expanduser("~/.ssh/known_hosts")
if os.path.exists(kh):
    try:
        with open(kh) as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    parts = line.split()
                    if parts:
                        part = parts[0]
                        if not part.startswith("|1|"):
                            for h in part.split(","):
                                h = re.sub(r"^\[|\](:\d+)?$", "", h)
                                hosts.add(h)
    except: pass
for h in sorted(hosts):
    print(h)
')
        extra_args=()
        if [[ -n "$PROMPT" ]]; then
            extra_args+=("-p" "$PROMPT")
        else
            extra_args+=("-p" "ssh")
        fi

        selected=$(echo "$hosts" | noctalia-dmenu "${extra_args[@]}")
        if [[ -n "$selected" ]]; then
            if command -v konsole &>/dev/null; then
                konsole -e ssh "$selected" &
            elif command -v alacritty &>/dev/null; then
                alacritty -e ssh "$selected" &
            else
                xterm -e ssh "$selected" &
            fi
        fi
        ;;

    filebrowser)
        current_dir="${FILTER:-$HOME}"
        if [[ ! -d "$current_dir" ]]; then
            current_dir="$HOME"
        fi

        while true; do
            items=$(printf "..\n"; find "$current_dir" -maxdepth 1 -mindepth 1 -printf "%y\t%P\n" 2>/dev/null | sort -t$'\t' -k2 | awk -F'\t' '{ if ($1 == "d") print $2 "/"; else print $2 }')
            extra_args=()
            extra_args+=("-p" "filebrowser: $(basename "$current_dir")")
            selected=$(echo "$items" | noctalia-dmenu "${extra_args[@]}")
            if [[ -z "$selected" ]]; then
                break
            fi
            if [[ "$selected" == ".." ]]; then
                current_dir=$(dirname "$current_dir")
            elif [[ "$selected" == */ ]]; then
                current_dir="${current_dir}/${selected%/}"
            else
                xdg-open "${current_dir}/${selected}" &
                break
            fi
        done
        ;;

    keys)
        keys_list=$(python3 -c '
import os, re
bindings = []
path = os.path.expanduser("~/.config/driftwm/config.toml")
if os.path.exists(path):
    in_keys = False
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("[keybindings]"):
                in_keys = True
                continue
            elif line.startswith("[") or line.startswith("[["):
                if in_keys:
                    in_keys = False
            if in_keys:
                m = re.match(r"^\"([^\"]+)\"\s*=\s*\"([^\"]+)\"", line)
                if m:
                    bindings.append(f"{m.group(1)}\t{m.group(2)}")
for b in bindings:
    print(b)
')
        names=$(echo "$keys_list" | cut -f1)
        extra_args=()
        if [[ -n "$PROMPT" ]]; then
            extra_args+=("-p" "$PROMPT")
        else
            extra_args+=("-p" "keys")
        fi

        selected=$(echo "$names" | noctalia-dmenu "${extra_args[@]}")
        if [[ -n "$selected" ]]; then
            action=$(echo "$keys_list" | awk -F'\t' -v sel="$selected" '$1 == sel {print $2}')
            if [[ -n "$action" ]]; then
                if [[ "$action" == "spawn "* ]]; then
                    cmd="${action#spawn }"
                    eval "$cmd &"
                elif [[ "$action" == "exec "* ]]; then
                    cmd="${action#exec }"
                    eval "$cmd &"
                else
                    driftwm msg action "$action"
                fi
            fi
        fi
        ;;

    *)
        echo "rofi: unknown mode '$SHOW_MODE'" >&2
        exit 1
        ;;
esac
