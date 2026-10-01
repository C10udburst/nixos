#!/usr/bin/env python3
"""
Caddy Log Viewer - DevTools Network Style CGI
- Top Panel: File Management Table with quick filtering, select/deselect all, and batch clearing.
- Draggable Splitter: Move to resize heights of the top and bottom panes.
- Bottom Panel: Chrome DevTools-styled network viewer with filters and side drawer for headers.
"""

import os
import sys
import json
import html
import urllib.parse
from datetime import datetime

LOG_DIR = "/var/log/caddy"
DEFAULT_LINE_LIMIT = 1000

# ---------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------

def format_bytes(size):
    try:
        size = float(size)
    except (ValueError, TypeError):
        return "0 B"
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(size) < 1024.0:
            return f"{size:3.1f} {unit}" if unit != 'B' else f"{int(size)} B"
        size /= 1024.0
    return f"{size:.1f} PB"

def format_duration(seconds):
    try:
        s = float(seconds)
        if s < 0.001:
            return f"{s * 1000000:.0f} µs"
        if s < 1.0:
            return f"{s * 1000:.1f} ms"
        return f"{s:.2f} s"
    except (ValueError, TypeError):
        return "-"

def read_reverse_lines(filepath, max_lines=1000, chunk_size=65536):
    """Efficiently tail the last N lines of large files without reading the whole file into RAM."""
    lines = []
    try:
        with open(filepath, 'rb') as f:
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            remainder = b""
            pos = file_size

            while pos > 0 and len(lines) < max_lines:
                read_len = min(chunk_size, pos)
                pos -= read_len
                f.seek(pos)
                chunk = f.read(read_len) + remainder
                chunk_lines = chunk.split(b'\n')
                remainder = chunk_lines[0]
                chunk_lines = chunk_lines[1:]

                for raw_l in reversed(chunk_lines):
                    l_str = raw_l.strip().decode('utf-8', errors='replace')
                    if l_str:
                        lines.append(l_str)
                        if len(lines) >= max_lines:
                            break
            if remainder and len(lines) < max_lines:
                l_str = remainder.strip().decode('utf-8', errors='replace')
                if l_str:
                    lines.append(l_str)
    except Exception as e:
        return [json.dumps({"error": f"Failed reading file: {str(e)}", "ts": 0})]
    return lines

# ---------------------------------------------------------
# CGI Request & Parameter Handling
# ---------------------------------------------------------

method = os.environ.get("REQUEST_METHOD", "GET").upper()
query_string = os.environ.get("QUERY_STRING", "")
params = urllib.parse.parse_qs(query_string)

post_data = {}
if method == "POST":
    try:
        length = int(os.environ.get("CONTENT_LENGTH", 0))
        raw_body = sys.stdin.read(length)
        post_data = urllib.parse.parse_qs(raw_body)
    except Exception:
        pass

# Discover files with size and modification timestamp
file_info_list = []
if os.path.exists(LOG_DIR) and os.path.isdir(LOG_DIR):
    for entry in sorted(os.listdir(LOG_DIR)):
        if entry.startswith('.'):
            continue
        p = os.path.join(LOG_DIR, entry)
        if os.path.isfile(p):
            stat = os.stat(p)
            file_info_list.append({
                "name": entry,
                "size": stat.st_size,
                "size_formatted": format_bytes(stat.st_size),
                "mtime": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            })

valid_file_names = {f["name"] for f in file_info_list}

# Action Handling: Clear single or multiple files
status_message = ""
action = post_data.get("action", [""])[0]

if method == "POST":
    if action == "clear_single":
        target = post_data.get("target_file", [""])[0]
        if target in valid_file_names:
            try:
                with open(os.path.join(LOG_DIR, target), "w") as f:
                    f.truncate(0)
                status_message = f"Cleared: {target}"
            except Exception as e:
                status_message = f"Error clearing {target}: {str(e)}"
    elif action == "clear_selected":
        targets = post_data.get("files", [])
        cleared_count = 0
        for t in targets:
            if t in valid_file_names:
                try:
                    with open(os.path.join(LOG_DIR, t), "w") as f:
                        f.truncate(0)
                    cleared_count += 1
                except Exception:
                    pass
        status_message = f"Cleared {cleared_count} selected log file(s)."

# Selected files to read
selected_files = post_data.get("files", params.get("files", []))
if not selected_files and valid_file_names and method != "POST":
    # Default to first file if fresh visit
    selected_files = [file_info_list[0]["name"]]

# Limit parameter
try:
    limit = int(post_data.get("limit", params.get("limit", [DEFAULT_LINE_LIMIT]))[0])
except (ValueError, IndexError):
    limit = DEFAULT_LINE_LIMIT

# ---------------------------------------------------------
# Read & Parse Logs
# ---------------------------------------------------------

records = []
hosts_found = set()
methods_found = set()

for fname in selected_files:
    if fname not in valid_file_names:
        continue
    fpath = os.path.join(LOG_DIR, fname)
    raw_lines = read_reverse_lines(fpath, max_lines=limit)

    for line in raw_lines:
        try:
            entry = json.loads(line)
        except Exception:
            continue

        req = entry.get("request", {})
        resp_headers = entry.get("resp_headers", {})
        ts_val = entry.get("ts", 0)
        dt = datetime.fromtimestamp(ts_val).strftime("%H:%M:%S.%f")[:-3] if ts_val else "-"

        m = req.get("method", "-")
        h = req.get("host", "-")
        uri = req.get("uri", "-")
        st = entry.get("status", 0)
        sz = entry.get("size", 0)
        dur = entry.get("duration", 0)
        ip = req.get("client_ip", req.get("remote_ip", "-"))

        ct = "-"
        if "Content-Type" in resp_headers and resp_headers["Content-Type"]:
            ct = resp_headers["Content-Type"][0].split(";")[0]

        if h: hosts_found.add(h)
        if m: methods_found.add(m)

        records.append({
            "source_file": fname,
            "ts": ts_val,
            "time": dt,
            "method": m,
            "host": h,
            "uri": uri,
            "status": st,
            "type": ct,
            "size_str": format_bytes(sz),
            "duration_str": format_duration(dur),
            "client_ip": ip,
            "raw": entry
        })

# Sort descending by timestamp
records.sort(key=lambda x: x["ts"], reverse=True)

# ---------------------------------------------------------
# HTML Response
# ---------------------------------------------------------

print("Content-Type: text/html; charset=utf-8\r\n\r\n")

print(f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Caddy DevTools Log Viewer</title>
<style>
  :root {{
    --bg-main: #202124;
    --bg-panel: #292a2d;
    --bg-hover: #35363a;
    --border: #3c4043;
    --text-primary: #e8eaed;
    --text-muted: #9aa0a6;
    --accent: #8ab4f8;
    --accent-hover: #aecbfa;
    --status-2xx: #81c995;
    --status-3xx: #8ab4f8;
    --status-4xx: #f28b82;
    --status-5xx: #ee675c;
    --font-mono: "SF Mono", Consolas, "Liberation Mono", Menlo, Courier, monospace;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: var(--bg-main);
    color: var(--text-primary);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    font-size: 12px;
    height: 100vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }}
  /* Header */
  header {{
    background: var(--bg-panel);
    border-bottom: 1px solid var(--border);
    padding: 6px 14px;
    display: flex;
    align-items: center;
    gap: 12px;
  }}
  .brand {{
    font-weight: 700;
    color: var(--accent);
    font-size: 13px;
    letter-spacing: 0.5px;
  }}
  .status-msg {{
    color: var(--status-2xx);
    font-size: 11px;
    margin-left: auto;
  }}

  /* Buttons & Inputs */
  input[type="text"], select {{
    background: var(--bg-main);
    border: 1px solid var(--border);
    color: var(--text-primary);
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 11px;
    outline: none;
  }}
  input[type="text"]:focus, select:focus {{
    border-color: var(--accent);
  }}
  .btn {{
    background: #3c4043;
    color: var(--text-primary);
    border: 1px solid var(--border);
    padding: 3px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 11px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }}
  .btn:hover {{ background: #4a4d51; }}
  .btn-primary {{ background: #1a73e8; border-color: #1a73e8; color: #fff; }}
  .btn-primary:hover {{ background: #1b66c9; }}
  .btn-danger {{ background: #5c2b29; color: #f28b82; border-color: #8c3835; }}
  .btn-danger:hover {{ background: #733432; }}

  /* Panes & Splitter */
  #top-pane {{
    height: 220px;
    min-height: 100px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    background: var(--bg-panel);
  }}
  #splitter {{
    height: 6px;
    background: var(--border);
    cursor: row-resize;
    transition: background 0.15s;
    user-select: none;
    z-index: 10;
  }}
  #splitter:hover, #splitter.active {{
    background: var(--accent);
  }}
  #bottom-pane {{
    flex: 1;
    min-height: 150px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }}

  /* Top Pane Toolbars */
  .toolbar {{
    padding: 6px 14px;
    display: flex;
    align-items: center;
    gap: 8px;
    border-bottom: 1px solid var(--border);
    flex-wrap: wrap;
  }}
  .table-scroll {{
    flex: 1;
    overflow: auto;
  }}

  /* Tables */
  table {{
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-mono);
    white-space: nowrap;
  }}
  th {{
    background: #25262a;
    position: sticky;
    top: 0;
    text-align: left;
    padding: 4px 8px;
    font-weight: 600;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border);
    border-right: 1px solid var(--border);
    z-index: 2;
  }}
  td {{
    padding: 3px 8px;
    border-bottom: 1px solid #2d3034;
    border-right: 1px solid #2d3034;
    overflow: hidden;
    text-overflow: ellipsis;
  }}
  tr:hover {{ background: var(--bg-hover); }}
  tr.selected {{ background: #2f3e55 !important; }}

  /* DevTools log table adjustments */
  #logs-table td {{ cursor: pointer; max-width: 380px; }}

  /* Status Color Codes */
  .s-2xx {{ color: var(--status-2xx); }}
  .s-3xx {{ color: var(--status-3xx); }}
  .s-4xx {{ color: var(--status-4xx); }}
  .s-5xx {{ color: var(--status-5xx); }}

  .badge {{
    font-size: 9px;
    padding: 1px 4px;
    border-radius: 3px;
    font-weight: bold;
    background: #333;
  }}
  .m-get {{ background: #1b3a2a; color: #81c995; }}
  .m-post {{ background: #3b3318; color: #fdd663; }}
  .m-delete {{ background: #401b19; color: #f28b82; }}

  /* Bottom Container & Side Drawer */
  #bottom-content {{
    flex: 1;
    display: flex;
    overflow: hidden;
  }}
  #logs-container {{
    flex: 1;
    overflow: auto;
  }}
  #detail-drawer {{
    width: 480px;
    border-left: 1px solid var(--border);
    background: var(--bg-panel);
    display: none;
    flex-direction: column;
    overflow-y: auto;
    font-family: var(--font-mono);
  }}
  .detail-header {{
    padding: 8px 12px;
    background: var(--bg-main);
    border-bottom: 1px solid var(--border);
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-weight: bold;
  }}
  .detail-section {{
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
  }}
  .detail-title {{
    color: var(--accent);
    font-size: 11px;
    font-weight: bold;
    text-transform: uppercase;
    margin-bottom: 6px;
  }}
  .kv-row {{
    display: flex;
    margin-bottom: 4px;
    word-break: break-all;
    white-space: pre-wrap;
  }}
  .kv-key {{ color: var(--text-muted); width: 140px; flex-shrink: 0; }}
  .kv-val {{ color: var(--text-primary); flex-grow: 1; }}
  pre {{
    white-space: pre-wrap;
    word-break: break-all;
    color: #ce9178;
    background: #18191c;
    padding: 8px;
    border-radius: 4px;
  }}
</style>
</head>
<body>

<header>
  <div class="brand">⚡ CADDY LOG VIEWER</div>
  <div class="status-msg">{html.escape(status_message)}</div>
</header>

<!-- TOP PANE: Log File Table & Actions -->
<div id="top-pane">
  <form id="action-form" method="POST" style="display:flex; flex-direction:column; height:100%;">
    <input type="hidden" name="action" id="action-input" value="load">
    <input type="hidden" name="target_file" id="target-file-input" value="">

    <div class="toolbar">
      <input type="text" id="file-filter" placeholder="Filter files..." style="width: 170px;" oninput="filterFiles()">
      <button type="button" class="btn" onclick="toggleSelectAll(true)">Select All</button>
      <button type="button" class="btn" onclick="toggleSelectAll(false)">Deselect All</button>

      <span style="color:var(--border);">|</span>

      <label style="display:inline-flex; align-items:center; gap:5px; color:var(--text-muted);">
        Show tail lines:
        <select name="limit" id="limit-select">
          <option value="500" {'selected' if limit==500 else ''}>Last 500 lines</option>
          <option value="1000" {'selected' if limit==1000 else ''}>Last 1,000 lines</option>
          <option value="3000" {'selected' if limit==3000 else ''}>Last 3,000 lines</option>
          <option value="5000" {'selected' if limit==5000 else ''}>Last 5,000 lines</option>
          <option value="10000" {'selected' if limit==10000 else ''}>Last 10,000 lines</option>
        </select>
      </label>

      <button type="button" class="btn btn-primary" onclick="submitLoad()">Load Selected</button>
      <button type="button" class="btn btn-danger" onclick="submitClearSelected()">Clear Selected</button>

      <span id="file-count" style="margin-left:auto; color:var(--text-muted);">
        {len(file_info_list)} files found
      </span>
    </div>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th style="width: 35px; text-align:center;">
              <input type="checkbox" id="th-checkbox" onclick="toggleSelectAll(this.checked)">
            </th>
            <th>Log File Name</th>
            <th style="width: 110px;">Size</th>
            <th style="width: 170px;">Last Modified</th>
            <th style="width: 90px; text-align:center;">Actions</th>
          </tr>
        </thead>
        <tbody id="files-tbody">
""")

for finfo in file_info_list:
    fname = finfo["name"]
    is_checked = "checked" if fname in selected_files else ""
    print(f"""
          <tr data-filename="{html.escape(fname.lower())}">
            <td style="text-align:center;">
              <input type="checkbox" name="files" value="{html.escape(fname)}" class="file-chk" {is_checked}>
            </td>
            <td><b>{html.escape(fname)}</b></td>
            <td>{finfo['size_formatted']}</td>
            <td>{finfo['mtime']}</td>
            <td style="text-align:center;">
              <button type="button" class="btn btn-danger" style="padding:1px 6px; font-size:10px;" onclick="submitClearSingle('{html.escape(fname)}')">Clear</button>
            </td>
          </tr>
    """)

if not file_info_list:
    print(f"""<tr><td colspan="5" style="text-align:center; padding:15px; color:var(--text-muted);">No log files found in {html.escape(LOG_DIR)}</td></tr>""")

print(f"""
        </tbody>
      </table>
    </div>
  </form>
</div>

<!-- DRAGGABLE SPLITTER -->
<div id="splitter" title="Drag to resize height"></div>

<!-- BOTTOM PANE: DevTools Log Stream -->
<div id="bottom-pane">
  <div class="toolbar" style="background:#25262a;">
    <input type="text" id="filter-search" placeholder="Filter URL, IP, path..." style="width: 220px;" oninput="applyFilters()">

    <select id="filter-domain" onchange="applyFilters()">
      <option value="">All Domains ({len(hosts_found)})</option>
""")

for h in sorted(hosts_found):
    if h and h != "-":
        print(f'<option value="{html.escape(h)}">{html.escape(h)}</option>')

print("""
    </select>

    <select id="filter-method" onchange="applyFilters()">
      <option value="">All Methods</option>
""")

for m in sorted(methods_found):
    if m and m != "-":
        print(f'<option value="{html.escape(m)}">{html.escape(m)}</option>')

print(f"""
    </select>

    <select id="filter-status" onchange="applyFilters()">
      <option value="">All Statuses</option>
      <option value="2xx">2xx Success</option>
      <option value="3xx">3xx Redirect</option>
      <option value="4xx">4xx Client Error</option>
      <option value="5xx">5xx Server Error</option>
    </select>

    <span id="log-count" style="margin-left:auto; color:var(--text-muted);">
      Showing {len(records)} entries
    </span>
  </div>

  <div id="bottom-content">
    <div id="logs-container">
      <table id="logs-table">
        <thead>
          <tr>
            <th style="width: 90px;">Time</th>
            <th style="width: 65px;">Status</th>
            <th style="width: 55px;">Method</th>
            <th style="width: 180px;">Host</th>
            <th>Path / URL</th>
            <th style="width: 100px;">Type</th>
            <th style="width: 70px;">Size</th>
            <th style="width: 70px;">Time</th>
            <th style="width: 120px;">Client IP</th>
            <th style="width: 95px;">Source</th>
          </tr>
        </thead>
        <tbody id="logs-body">
""")

for i, rec in enumerate(records):
    status_class = f"s-{str(rec['status'])[0]}xx" if rec['status'] else ""
    method_class = f"m-{rec['method'].lower()}" if rec['method'] in ["GET", "POST", "DELETE"] else ""
    json_attr = html.escape(json.dumps(rec["raw"]), quote=True)

    print(f"""
          <tr onclick="showDetails({i}, this)"
              data-raw="{json_attr}"
              data-host="{html.escape(rec['host'])}"
              data-method="{html.escape(rec['method'])}"
              data-status="{rec['status']}"
              data-search="{html.escape((rec['uri'] + ' ' + rec['client_ip'] + ' ' + rec['host']).lower())}">
            <td>{rec['time']}</td>
            <td class="{status_class}"><b>{rec['status']}</b></td>
            <td><span class="badge {method_class}">{rec['method']}</span></td>
            <td title="{html.escape(rec['host'])}">{html.escape(rec['host'])}</td>
            <td title="{html.escape(rec['uri'])}">{html.escape(rec['uri'])}</td>
            <td>{html.escape(rec['type'])}</td>
            <td>{rec['size_str']}</td>
            <td>{rec['duration_str']}</td>
            <td>{html.escape(rec['client_ip'])}</td>
            <td><span style="color:var(--text-muted);">{html.escape(rec['source_file'])}</span></td>
          </tr>
    """)

print("""
        </tbody>
      </table>
    </div>

    <!-- DevTools Slide-over Drawer -->
    <div id="detail-drawer">
      <div class="detail-header">
        <span>Request Details</span>
        <button type="button" class="btn" onclick="closeDetails()">✕</button>
      </div>
      <div id="detail-content"></div>
    </div>
  </div>
</div>

<script>
// --- RESIZE SPLITTER LOGIC ---
const topPane = document.getElementById('top-pane');
const splitter = document.getElementById('splitter');
let isDragging = false;

// Restore saved top pane height
const savedHeight = localStorage.getItem('caddy_top_pane_height');
if (savedHeight) {
  topPane.style.height = savedHeight + 'px';
}

splitter.addEventListener('mousedown', (e) => {
  isDragging = true;
  splitter.classList.add('active');
  document.body.style.cursor = 'row-resize';
  e.preventDefault();
});

window.addEventListener('mousemove', (e) => {
  if (!isDragging) return;
  const newHeight = Math.max(80, Math.min(window.innerHeight - 150, e.clientY));
  topPane.style.height = newHeight + 'px';
  localStorage.setItem('caddy_top_pane_height', newHeight);
});

window.addEventListener('mouseup', () => {
  if (isDragging) {
    isDragging = false;
    splitter.classList.remove('active');
    document.body.style.cursor = '';
  }
});

// --- TOP TABLE FILE ACTIONS ---
function filterFiles() {
  const query = document.getElementById('file-filter').value.toLowerCase().trim();
  const rows = document.querySelectorAll('#files-tbody tr');
  let visible = 0;
  rows.forEach(r => {
    const fn = r.getAttribute('data-filename');
    if (!fn || fn.includes(query)) {
      r.style.display = '';
      visible++;
    } else {
      r.style.display = 'none';
    }
  });
  document.getElementById('file-count').textContent = `${visible} files shown`;
}

function toggleSelectAll(select) {
  const checkboxes = document.querySelectorAll('.file-chk');
  checkboxes.forEach(cb => {
    // Only toggle visible rows if filtered
    if (cb.closest('tr').style.display !== 'none') {
      cb.checked = select;
    }
  });
}

function submitLoad() {
  document.getElementById('action-input').value = 'load';
  document.getElementById('action-form').submit();
}

function submitClearSelected() {
  const checked = document.querySelectorAll('.file-chk:checked');
  if (checked.length === 0) {
    alert('Please select at least one file to clear.');
    return;
  }
  if (confirm(`Are you sure you want to clear ${checked.length} selected log file(s)? This will truncate them to 0 bytes.`)) {
    document.getElementById('action-input').value = 'clear_selected';
    document.getElementById('action-form').submit();
  }
}

function submitClearSingle(filename) {
  if (confirm(`Are you sure you want to clear "${filename}"?`)) {
    document.getElementById('action-input').value = 'clear_single';
    document.getElementById('target-file-input').value = filename;
    document.getElementById('action-form').submit();
  }
}

// --- BOTTOM TABLE FILTERING LOGIC ---
function applyFilters() {
  const search = document.getElementById("filter-search").value.toLowerCase();
  const domain = document.getElementById("filter-domain").value;
  const method = document.getElementById("filter-method").value;
  const statusGroup = document.getElementById("filter-status").value;

  const rows = document.querySelectorAll("#logs-body tr");
  let visibleCount = 0;

  rows.forEach(r => {
    const rowHost = r.getAttribute("data-host");
    const rowMethod = r.getAttribute("data-method");
    const rowStatus = r.getAttribute("data-status");
    const rowSearch = r.getAttribute("data-search");

    let match = true;
    if (search && !rowSearch.includes(search)) match = false;
    if (domain && rowHost !== domain) match = false;
    if (method && rowMethod !== method) match = false;
    if (statusGroup && !rowStatus.startsWith(statusGroup[0])) match = false;

    if (match) {
      r.style.display = "";
      visibleCount++;
    } else {
      r.style.display = "none";
    }
  });

  document.getElementById("log-count").textContent = `Showing ${visibleCount} entries`;
}

// --- DEVTOOLS DETAIL DRAWER ---
let activeRow = null;

function showDetails(index, row) {
  if (activeRow) activeRow.classList.remove("selected");
  activeRow = row;
  activeRow.classList.add("selected");

  const rawData = JSON.parse(row.getAttribute("data-raw"));
  const drawer = document.getElementById("detail-drawer");
  const content = document.getElementById("detail-content");

  drawer.style.display = "flex";

  const req = rawData.request || {};
  const respHeaders = rawData.resp_headers || {};
  const reqHeaders = req.headers || {};
  const tls = req.tls || {};

  function renderKV(obj) {
    let out = "";
    for (const [k, v] of Object.entries(obj)) {
      const val = Array.isArray(v) ? v.join(", ") : v;
      out += `<div class="kv-row"><div class="kv-key">${escapeHtml(k)}:</div><div class="kv-val">${escapeHtml(String(val))}</div></div>`;
    }
    return out || "<span style='color:var(--text-muted)'>None</span>";
  }

  content.innerHTML = `
    <div class="detail-section">
      <div class="detail-title">General</div>
      <div class="kv-row"><div class="kv-key">Request URL:</div><div class="kv-val">https://${escapeHtml(req.host || '')}${escapeHtml(req.uri || '')}</div></div>
      <div class="kv-row"><div class="kv-key">Request Method:</div><div class="kv-val">${escapeHtml(req.method || '-')}</div></div>
      <div class="kv-row"><div class="kv-key">Status Code:</div><div class="kv-val">${escapeHtml(String(rawData.status || '-'))}</div></div>
      <div class="kv-row"><div class="kv-key">Remote Address:</div><div class="kv-val">${escapeHtml(req.remote_ip || '-')}:${escapeHtml(req.remote_port || '')}</div></div>
      <div class="kv-row"><div class="kv-key">Client IP:</div><div class="kv-val">${escapeHtml(req.client_ip || '-')}</div></div>
      <div class="kv-row"><div class="kv-key">Duration:</div><div class="kv-val">${rawData.duration || 0}s</div></div>
    </div>

    <div class="detail-section">
      <div class="detail-title">Response Headers</div>
      ${renderKV(respHeaders)}
    </div>

    <div class="detail-section">
      <div class="detail-title">Request Headers</div>
      ${renderKV(reqHeaders)}
    </div>

    <div class="detail-section">
      <div class="detail-title">TLS Connection</div>
      <div class="kv-row"><div class="kv-key">Server Name:</div><div class="kv-val">${escapeHtml(tls.server_name || '-')}</div></div>
      <div class="kv-row"><div class="kv-key">Protocol:</div><div class="kv-val">${escapeHtml(tls.proto || '-')}</div></div>
      <div class="kv-row"><div class="kv-key">Resumed:</div><div class="kv-val">${escapeHtml(String(tls.resumed || false))}</div></div>
    </div>

    <div class="detail-section">
      <div class="detail-title">Raw Log JSON</div>
      <pre>${escapeHtml(JSON.stringify(rawData, null, 2))}</pre>
    </div>
  `;
}

function closeDetails() {
  document.getElementById("detail-drawer").style.display = "none";
  if (activeRow) activeRow.classList.remove("selected");
}

function escapeHtml(text) {
  if (!text) return "";
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}
</script>
</body>
</html>
""")
