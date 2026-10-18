#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
metube_add.py - CGI helper that queues a download in MeTube (ytdlp) from any URL.

GET  /metube_add?url=<media_url>   -> dark-themed form, prefilled with the URL
POST                               -> calls POST <METUBE_BASE>/add, then redirects to the MeTube UI

Configure via environment variables:
  METUBE_BASE            upstream API, e.g. http://127.0.0.1:8081
  METUBE_WAKE_URL        public URL used to wake a suspended instance (Sablier)
  METUBE_REDIRECT_AFTER  where to land after queueing, defaults to METUBE_WAKE_URL
  METUBE_CGI_TOKEN       if set, requests must carry the matching token

The download options (type / codec / format / quality) are read from
GET /formats instead of being hardcoded, so the form follows MeTube itself.
Form parsing is stdlib-only because the cgi module is gone in Python 3.13.
"""

import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CSS = """
:root{--bg:#1f2329;--panel:#2a2f3a;--panel2:#242935;--text:#d7dce2;--muted:#9aa4af;
--border:#3a4150;--accent:#4aa3ff;--danger:#ff6b6b;--radius:10px;
--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;--sans:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
*{box-sizing:border-box}
body{margin:0;font-family:var(--sans);background:linear-gradient(180deg,#1b1f25,var(--bg));color:var(--text)}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
.container{max-width:860px;margin:40px auto;padding:0 16px}
.card{background:var(--panel);border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.header{padding:18px 20px;background:linear-gradient(180deg,var(--panel2),var(--panel));border-bottom:1px solid var(--border)}
.header h1{margin:0;font-size:18px}
.header p{margin:8px 0 0;color:var(--muted);font-size:13px}
.content{padding:18px 20px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media (max-width:700px){.grid{grid-template-columns:1fr}}
.label{display:block;font-size:13px;color:var(--muted);margin:0 0 6px}
input[type="text"],select{width:100%;padding:10px 12px;background:#171a21;border:1px solid var(--border);
border-radius:8px;color:var(--text);outline:none;font-size:14px}
input[type="text"]:focus,select:focus{border-color:rgba(74,163,255,.75);box-shadow:0 0 0 3px rgba(74,163,255,.15)}
select[multiple]{min-height:96px}
.small{font-size:12px;color:var(--muted);margin-top:6px}
.mono{font-family:var(--mono);font-size:12px;color:#c5ccd6}
.row{margin-bottom:14px}
.checks{display:flex;gap:18px;align-items:center;flex-wrap:wrap;font-size:13px}
.actions{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-top:18px}
button,.btn{background:linear-gradient(180deg,#5bb0ff,#2f8fff);color:#071018;border:none;border-radius:10px;
padding:10px 14px;font-weight:650;cursor:pointer;display:inline-block}
button:hover,.btn:hover{filter:brightness(1.05)}
.btn-secondary{background:transparent;border:1px solid var(--border);color:var(--text);font-weight:400}
.note{border:1px solid var(--border);background:#171a21;border-radius:10px;padding:12px;color:var(--muted);font-size:13px}
.error{border-color:rgba(255,107,107,.6);color:#ffd1d1}
.footer{padding:12px 20px;border-top:1px solid var(--border);color:var(--muted);font-size:12px;
display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap}
"""


def base() -> str:
    return os.environ.get("METUBE_BASE", "http://127.0.0.1:8081").rstrip("/")


def wake_url() -> str:
    return os.environ.get("METUBE_WAKE_URL", "").rstrip("/")


def redirect_after() -> str:
    return os.environ.get("METUBE_REDIRECT_AFTER") or f"{wake_url() or base()}/"


def token_required() -> str:
    return os.environ.get("METUBE_CGI_TOKEN", "")


def headers() -> dict:
    return {"Accept": "application/json", "Content-Type": "application/json"}


def api(method: str, path: str, payload=None):
    """Returns (status, parsed_json_or_None, raw_text)."""
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(base() + path, method=method, data=data, headers=headers())
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace") if e.fp else e.reason
        return e.code, None, raw
    except Exception as e:
        return 0, None, str(e)
    try:
        return 200, json.loads(raw), raw
    except json.JSONDecodeError:
        return 200, None, raw


def wake_up():
    """Poke the public URL until MeTube answers, so a suspended instance is running."""
    target = wake_url()
    if not target:
        return
    for _ in range(40):
        try:
            with urllib.request.urlopen(target + "/version", timeout=5) as resp:
                if resp.status == 200:
                    return
        except Exception:
            pass
        time.sleep(0.5)


def is_http_url(u: str) -> bool:
    if not u or len(u) > 4000 or re.search(r"[\x00-\x20]", u):
        return False
    p = urllib.parse.urlsplit(u)
    return p.scheme in ("http", "https") and bool(p.netloc)


def params() -> dict:
    """Query string and urlencoded POST body merged; every key maps to a list."""
    body = ""
    if (os.environ.get("REQUEST_METHOD") or "GET").upper() == "POST":
        try:
            length = max(0, min(int(os.environ.get("CONTENT_LENGTH") or 0), 65536))
        except ValueError:
            length = 0
        body = sys.stdin.read(length) if length else ""
    return urllib.parse.parse_qs(f"{os.environ.get('QUERY_STRING', '')}&{body}", keep_blank_values=True)


def first(form: dict, key: str, default: str = "") -> str:
    return (form.get(key) or [default])[0].strip()


LABELS = {
    "download_type": "Download type",
    "codec": "Codec",
    "format": "Format",
    "quality": "Quality",
}


def esc(s) -> str:
    return html.escape(str(s if s is not None else ""), quote=True)


def print_headers(status: str = "200 OK", extra=None):
    print(f"Status: {status}")
    for k, v in (extra or []):
        print(f"{k}: {v}")
    print("Content-Type: text/html; charset=utf-8")
    print("Cache-Control: no-store")
    print()


def render_page(title: str, body: str) -> None:
    print_headers()
    print(
        f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{esc(title)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="container"><div class="card">{body}</div></div>
</body>
</html>"""
    )


def render_error(title: str, message: str, details: str = "") -> None:
    detail_html = f"<pre class='mono'>{esc(details)}</pre>" if details else ""
    render_page(
        title,
        f"""
<div class="header"><h1>{esc(title)}</h1><p>Nothing was queued.</p></div>
<div class="content">
  <div class="note error"><div>{esc(message)}</div>{detail_html}</div>
  <div class="actions"><a class="btn btn-secondary" href="javascript:history.back()">Go back</a></div>
</div>
""",
    )


def select(name: str, choice: dict) -> str:
    """One option field; the row stays hidden when the default type offers nothing."""
    options = [(o.get("id"), o.get("text")) for o in (choice or {}).get("options", [])]
    default = (choice or {}).get("default")
    items = "\n".join(
        f'<option value="{esc(oid)}"{" selected" if oid == default else ""}>{esc(text)}</option>'
        for oid, text in options
    )
    hidden = "" if options else ' style="display:none"'
    return (
        f'<div class="row" id="row-{name}"{hidden}>'
        f'<label class="label" for="{name}">{LABELS[name]}</label>'
        f'<select id="{name}" name="{name}">{items}</select></div>'
    )


def render_form(media_url: str, catalog: dict, presets: list) -> None:
    script = esc(os.environ.get("SCRIPT_NAME", "") or "")
    types = catalog["download_type"]["options"]
    default_type = next((t for t in types if t["id"] == catalog["download_type"].get("default")), types[0])

    format_choice = default_type.get("format") or {}
    default_format = next(
        (f for f in format_choice.get("options", []) if f.get("id") == format_choice.get("default")),
        {},
    )
    selects = "".join(
        [
            select("download_type", catalog["download_type"]),
            select("codec", default_type.get("codec")),
            select("format", format_choice),
            select("quality", default_format.get("quality")),
        ]
    )

    preset_html = ""
    if presets:
        options = "\n".join(f'<option value="{esc(p)}">{esc(p)}</option>' for p in presets)
        preset_html = f"""
<div class="row">
  <label class="label" for="presets">yt-dlp option presets</label>
  <select id="presets" name="presets" multiple>{options}</select>
  <div class="small">Optional, combine several. Configured server-side in MeTube.</div>
</div>"""

    token = esc(token_required())
    render_page(
        "Add to ytdlp",
        f"""
<div class="header">
  <h1>Add to ytdlp</h1>
  <p>Queue a download in MeTube from any video URL.</p>
</div>
<div class="content">
  <form method="post" action="{script}">
    <div class="row">
      <label class="label" for="url">Media URL</label>
      <input id="url" name="url" type="text" value="{esc(media_url)}" required autofocus />
    </div>
    <div class="grid">{selects}</div>
    {preset_html}
    <div class="checks row">
      <label><input type="checkbox" name="sponsorblock" value="1" /> Cut SponsorBlock segments</label>
    </div>
    <input type="hidden" name="token" value="{token}" />
    <div class="actions">
      <button type="submit">Queue download</button>
      <a class="btn btn-secondary" href="{esc(redirect_after())}">Open MeTube</a>
    </div>
  </form>
</div>
<div class="footer">
  <span>MeTube: <span class="mono">{esc(base())}</span></span>
  <span>Options from <span class="mono">GET /formats</span></span>
</div>
<script>
const CATALOG = {json.dumps(catalog)};
const el = (id) => document.getElementById(id);
function fill(name, choice) {{
  const sel = el(name);
  if (!sel) return;
  const box = el('row-' + name);
  if (box) box.style.display = choice ? '' : 'none';
  if (!choice) return;
  sel.innerHTML = '';
  choice.options.forEach((o) => {{
    const opt = document.createElement('option');
    opt.value = o.id;
    opt.textContent = o.text;
    if (o.id === choice.default) opt.selected = true;
    sel.appendChild(opt);
  }});
}}
const typeEntry = () => (CATALOG.download_type.options.find((t) => t.id === el('download_type').value) || {{}});
function syncQuality() {{
  const fmt = ((typeEntry().format || {{}}).options || []).find((f) => f.id === el('format').value) || {{}};
  fill('quality', fmt.quality);
}}
function syncType() {{
  const entry = typeEntry();
  fill('codec', entry.codec);
  fill('format', entry.format);
  syncQuality();
}}
el('download_type').addEventListener('change', syncType);
el('format').addEventListener('change', syncQuality);
</script>
""",
    )


def handle_submit(form: dict) -> None:
    if token_required() and first(form, "token") != token_required():
        render_error("Forbidden", "Missing or wrong token.")
        return

    media_url = first(form, "url")
    if not is_http_url(media_url):
        render_error("Bad request", "Provide a valid http(s) URL in the url field.")
        return

    payload = {
        "url": media_url,
        "download_type": first(form, "download_type", "video").lower(),
        "codec": first(form, "codec", "auto").lower(),
        "format": first(form, "format", "any").lower(),
        "quality": first(form, "quality", "best").lower(),
    }
    presets = form.get("presets") or []
    if presets:
        payload["ytdl_options_presets"] = presets
    if form.get("sponsorblock"):
        payload["sponsorblock"] = True

    status, _, raw = api("POST", "/add", payload)
    if status not in (200, 201):
        render_error("MeTube refused the download", f"MeTube returned HTTP {status}.", raw)
        return

    location = redirect_after()
    print_headers(
        "303 See Other",
        [("Location", location), ("Content-Type", "text/plain; charset=utf-8")],
    )
    print(f'Queued. Redirecting to <a href="{esc(location)}">{esc(location)}</a>…')


def main() -> None:
    form = params()
    if (os.environ.get("REQUEST_METHOD") or "GET").upper() == "POST":
        handle_submit(form)
        return

    wake_up()
    status, catalog, raw = api("GET", "/formats")
    if status != 200 or not isinstance(catalog, dict) or "download_type" not in catalog:
        render_error("MeTube unreachable", "Could not read the download options from MeTube.", raw)
        return

    _, preset_data, _ = api("GET", "/presets")
    presets = preset_data.get("presets", []) if isinstance(preset_data, dict) else []
    render_form(first(form, "url"), catalog, presets)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # keep fcgiwrap/caddy happy: always emit a valid CGI response
        print_headers("500 Internal Server Error")
        print(f"<pre>{esc(repr(e))}</pre>")
