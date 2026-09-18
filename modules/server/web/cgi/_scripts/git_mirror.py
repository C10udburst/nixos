#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
git_mirror.py - Minimal CGI helper to create a Gitea "migration" (repo import) from an arbitrary Git URL.

GET  /cgi-bin/git_mirror.py?url=<source_url>
  - Shows a dark-themed HTML form:
      * Source URL (prefilled from query param)
      * Owner dropdown (current user + orgs)
      * Repo name (prefilled)
      * Mirror + Private checkboxes
      * Optional auth fields for private sources
POST
  - Calls Gitea API POST /api/v1/repos/migrate
  - Redirects (303) to the created repository page (html_url from API)

Configure via environment variables:
  GITEA_BASE_URL   e.g. https://git.example.com
  GITEA_TOKEN      personal access token with appropriate scopes/permissions

Security: protect this CGI endpoint (VPN, IP allowlist, HTTP auth, etc.).
"""

import cgi
import html
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional, Tuple


API_PREFIX = "/api/v1"


def _gitea_base() -> str:
    return os.environ.get("GITEA_BASE_URL", "https://git.brix0.wilkins.pl.eu.org/").rstrip("/")


def _gitea_token() -> str:
    return os.environ.get("GITEA_TOKEN", "")


def _http_json(
    method: str,
    url: str,
    token: str,
    body: Optional[Dict[str, Any]] = None,
) -> Tuple[int, Dict[str, Any], str]:
    """
    Returns (status_code, json_dict, raw_text)
    """
    headers = {"Accept": "application/json"}
    if token:
        # Gitea uses "Authorization: token <TOKEN>"
        headers["Authorization"] = f"token {token}"

    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url=url, method=method.upper(), headers=headers, data=data)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", "replace")
            if raw.strip():
                try:
                    return resp.status, json.loads(raw), raw
                except json.JSONDecodeError:
                    return resp.status, {}, raw
            return resp.status, {}, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace") if e.fp else ""
        try:
            return e.code, json.loads(raw) if raw.strip() else {}, raw
        except json.JSONDecodeError:
            return e.code, {}, raw
    except Exception as e:
        return 0, {}, str(e)


def gitea_api(
    method: str,
    path: str,
    token: str,
    body: Optional[Dict[str, Any]] = None,
) -> Tuple[int, Dict[str, Any], str]:
    base = _gitea_base()
    if not base:
        return 0, {}, "GITEA_BASE_URL is not set"
    url = base + API_PREFIX + path
    return _http_json(method, url, token, body)


def normalize_source_url(raw: str) -> str:
    """
    Attempt to turn a "web URL" (repo page) into a clone-able URL for common Git hosts,
    while staying reasonably generic.
    """
    raw = (raw or "").strip()
    if not raw:
        return ""
    # If it looks like an scp-style SSH URL, keep as-is.
    if re.match(r"^[\w.-]+@[\w.-]+:[\w./-]+(\.git)?$", raw):
        return raw

    try:
        u = urllib.parse.urlsplit(raw)
    except Exception:
        return raw

    if u.scheme not in ("http", "https"):
        return raw

    path = u.path or "/"

    # GitLab: "/-/" is used for subpages like /-/tree/...
    if "/-/" in path:
        path = path.split("/-/", 1)[0]

    # GitHub/Gitea/etc: strip common subpaths (best-effort)
    for marker in ("/tree/", "/blob/", "/pull/", "/pulls/", "/issues/", "/wiki", "/compare/"):
        if marker in path:
            path = path.split(marker, 1)[0]

    path = path.rstrip("/")

    if path.endswith(".git"):
        new_path = path
    else:
        new_path = path + ".git"

    return urllib.parse.urlunsplit((u.scheme, u.netloc, new_path, "", ""))


def default_repo_name_from_url(source_url: str) -> str:
    s = (source_url or "").strip()
    if not s:
        return ""

    # SSH scp-style
    m = re.match(r"^[\w.-]+@[\w.-]+:([\w./-]+?)(\.git)?$", s)
    if m:
        tail = m.group(1).rstrip("/").split("/")[-1]
        return tail

    try:
        u = urllib.parse.urlsplit(s)
        path = (u.path or "").rstrip("/")
        if path.endswith(".git"):
            path = path[:-4]
        return path.split("/")[-1] if path else ""
    except Exception:
        s2 = s.rstrip("/")
        if s2.endswith(".git"):
            s2 = s2[:-4]
        return s2.split("/")[-1]


def html_escape(s: str) -> str:
    return html.escape(s or "", quote=True)


def print_headers(status: str = "200 OK", extra_headers: Optional[List[Tuple[str, str]]] = None) -> None:
    print(f"Status: {status}")
    if extra_headers:
        for k, v in extra_headers:
            print(f"{k}: {v}")
    print("Content-Type: text/html; charset=utf-8")
    print("Cache-Control: no-store")
    print()


def render_page(title: str, body_html: str) -> None:
    css = """
:root{
  --bg:#1f2329;
  --panel:#2a2f3a;
  --panel2:#242935;
  --text:#d7dce2;
  --muted:#9aa4af;
  --border:#3a4150;
  --accent:#4aa3ff;
  --danger:#ff6b6b;
  --shadow:0 8px 24px rgba(0,0,0,.35);
  --radius:10px;
  --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  --sans: system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,Helvetica,Arial,sans-serif;
}
*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0;
  font-family:var(--sans);
  background:linear-gradient(180deg,#1b1f25, var(--bg));
  color:var(--text);
}
a{color:var(--accent); text-decoration:none}
a:hover{text-decoration:underline}
.container{
  max-width:980px;
  margin:40px auto;
  padding:0 16px;
}
.card{
  background:var(--panel);
  border:1px solid var(--border);
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  overflow:hidden;
}
.header{
  padding:18px 20px;
  background:linear-gradient(180deg,var(--panel2), var(--panel));
  border-bottom:1px solid var(--border);
}
.header h1{
  margin:0;
  font-size:18px;
  font-weight:650;
  letter-spacing:.2px;
}
.header p{
  margin:8px 0 0;
  color:var(--muted);
  font-size:13px;
}
.content{padding:18px 20px}
.grid{
  display:grid;
  grid-template-columns: 1fr 1fr;
  gap:14px;
}
@media (max-width:800px){ .grid{grid-template-columns:1fr;} }
.label{
  display:block;
  font-size:13px;
  color:var(--muted);
  margin:0 0 6px;
}
input[type="text"], input[type="password"], select{
  width:100%;
  padding:10px 12px;
  background:#171a21;
  border:1px solid var(--border);
  border-radius:8px;
  color:var(--text);
  outline:none;
}
input[type="text"]:focus, input[type="password"]:focus, select:focus{
  border-color:rgba(74,163,255,.75);
  box-shadow:0 0 0 3px rgba(74,163,255,.15);
}
.small{
  font-size:12px;
  color:var(--muted);
  margin-top:6px;
}
.mono{
  font-family:var(--mono);
  font-size:12px;
  color:#c5ccd6;
}
.row{margin-bottom:14px}
.checks{
  display:flex;
  gap:18px;
  align-items:center;
  flex-wrap:wrap;
}
.checks label{
  display:flex;
  align-items:center;
  gap:8px;
  color:var(--text);
  font-size:13px;
}
.actions{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  flex-wrap:wrap;
  margin-top:18px;
}
button{
  appearance:none;
  border:none;
  border-radius:10px;
  padding:10px 14px;
  font-weight:650;
  cursor:pointer;
}
.btn-primary{
  background:linear-gradient(180deg,#5bb0ff,#2f8fff);
  color:#071018;
}
.btn-primary:hover{filter:brightness(1.05)}
.btn-secondary{
  background:transparent;
  border:1px solid var(--border);
  color:var(--text);
}
.btn-secondary:hover{border-color:#55607a}
.note{
  border:1px solid var(--border);
  background:#171a21;
  border-radius:10px;
  padding:12px;
  color:var(--muted);
  font-size:13px;
}
.error{
  border-color:rgba(255,107,107,.6);
  color:#ffd1d1;
}
.footer{
  padding:12px 20px;
  border-top:1px solid var(--border);
  color:var(--muted);
  font-size:12px;
  display:flex;
  justify-content:space-between;
  gap:10px;
  flex-wrap:wrap;
}
"""
    print_headers()
    print(f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>{html_escape(title)}</title>
  <style>{css}</style>
</head>
<body>
  <div class="container">
    <div class="card">
      {body_html}
    </div>
  </div>
</body>
</html>""")


def render_error(title: str, message: str, details: str = "") -> None:
    details_html = f"<pre class='mono'>{html_escape(details)}</pre>" if details else ""
    body = f"""
<div class="header">
  <h1>{html_escape(title)}</h1>
  <p>Something went wrong.</p>
</div>
<div class="content">
  <div class="note error">
    <div>{html_escape(message)}</div>
    {details_html}
  </div>
  <div class="actions">
    <a class="btn-secondary" style="display:inline-block;padding:10px 14px;border-radius:10px;" href="javascript:history.back()">Go back</a>
  </div>
</div>
<div class="footer">
  <span>git_mirror.py</span>
  <span></span>
</div>
"""
    render_page(title, body)


def get_user_and_orgs(token: str) -> Tuple[Optional[Dict[str, Any]], List[Dict[str, Any]], Optional[str]]:
    status_u, user, raw_u = gitea_api("GET", "/user", token)
    if status_u != 200:
        return None, [], f"/user failed ({status_u}): {raw_u or user}"

    status_o, orgs, raw_o = gitea_api("GET", "/user/orgs", token)
    if status_o != 200:
        return user, [], f"/user/orgs failed ({status_o}): {raw_o or orgs}"

    if not isinstance(orgs, list):
        return user, [], f"/user/orgs returned non-list: {raw_o or orgs}"
    return user, orgs, None


def render_form(source_url_raw: str) -> None:
    token = _gitea_token()
    if not _gitea_base():
        render_error("Misconfigured", "GITEA_BASE_URL is not set in the CGI environment.")
        return
    if not token:
        render_error("Misconfigured", "GITEA_TOKEN is not set in the CGI environment.")
        return

    source_url_norm = normalize_source_url(source_url_raw)
    repo_name = default_repo_name_from_url(source_url_norm) or "repo"

    user, orgs, err = get_user_and_orgs(token)
    if err:
        render_error("Gitea API error", "Unable to load user/org list from Gitea.", err)
        return

    username = str(user.get("login") or user.get("username") or "")
    owner_options: List[Tuple[str, str]] = []
    if username:
        owner_options.append((username, f"{username} (you)"))
    for org in orgs:
        u = str(org.get("username") or "")
        label = str(org.get("full_name") or u)
        if u:
            owner_options.append((u, label))

    owner_select_html = "\n".join(
        f'<option value="{html_escape(val)}">{html_escape(label)}</option>'
        for val, label in owner_options
    ) or '<option value="">(no organizations found)</option>'

    script = html_escape(os.environ.get("SCRIPT_NAME", "") or "")

    body = f"""
<div class="header">
  <h1>New repository migration</h1>
  <p>Create a migration/import in Gitea from an arbitrary Git URL.</p>
</div>

<div class="content">
  <form method="post" action="{script}">
    <div class="grid">
      <div class="row">
        <label class="label" for="repo_owner">Target owner (user/org)</label>
        <select id="repo_owner" name="repo_owner" required>
          {owner_select_html}
        </select>
        <div class="small">Loaded from <span class="mono">GET /api/v1/user</span> and <span class="mono">GET /api/v1/user/orgs</span>.</div>
      </div>

      <div class="row">
        <label class="label" for="repo_name">Repository name</label>
        <input id="repo_name" name="repo_name" type="text" value="{html_escape(repo_name)}" pattern="[A-Za-z0-9._-]+" required />
        <div class="small">Defaulted from the source URL; adjust if needed.</div>
      </div>
    </div>

    <div class="row">
      <label class="label" for="clone_addr">Source (clone) URL</label>
      <input id="clone_addr" name="clone_addr" type="text" value="{html_escape(source_url_norm)}" required />
      <div class="small">Original input: <span class="mono">{html_escape(source_url_raw or "")}</span></div>
    </div>

    <div class="checks row">
      <label><input type="checkbox" name="mirror" value="1" checked /> Mirror</label>
      <label><input type="checkbox" name="private" value="1" /> Private</label>
    </div>

    <details class="row">
      <summary style="cursor:pointer;color:var(--muted);">Advanced: authentication for private sources</summary>
      <div style="margin-top:12px" class="grid">
        <div class="row">
          <label class="label" for="auth_username">Auth username</label>
          <input id="auth_username" name="auth_username" type="text" value="" />
        </div>
        <div class="row">
          <label class="label" for="auth_password">Auth password</label>
          <input id="auth_password" name="auth_password" type="password" value="" />
        </div>
        <div class="row" style="grid-column:1/-1">
          <label class="label" for="auth_token">Auth token (PAT)</label>
          <input id="auth_token" name="auth_token" type="password" value="" />
          <div class="small">If both username/password and token are provided, both are sent to the API.</div>
        </div>
      </div>
    </details>

    <input type="hidden" name="source_url_raw" value="{html_escape(source_url_raw or "")}" />

    <div class="actions">
      <button class="btn-primary" type="submit">Create migration</button>
      <a class="btn-secondary" style="display:inline-block;padding:10px 14px;" href="{html_escape(_gitea_base())}">Open Gitea</a>
    </div>

    <div class="note" style="margin-top:16px;">
      This calls <span class="mono">POST /api/v1/repos/migrate</span> with <span class="mono">service=git</span> and redirects to the created repository.
      Ensure your token has permissions to create repositories for the selected owner.
    </div>
  </form>
</div>

<div class="footer">
  <span>Gitea: <span class="mono">{html_escape(_gitea_base())}</span></span>
  <span>User: <span class="mono">{html_escape(username)}</span></span>
</div>
"""
    render_page("Gitea migration", body)


def handle_submit(fs: cgi.FieldStorage) -> None:
    token = _gitea_token()
    if not _gitea_base() or not token:
        render_error("Misconfigured", "GITEA_BASE_URL or GITEA_TOKEN missing.")
        return

    repo_owner = (fs.getfirst("repo_owner") or "").strip()
    repo_name = (fs.getfirst("repo_name") or "").strip()
    clone_addr = (fs.getfirst("clone_addr") or "").strip()
    mirror = bool(fs.getfirst("mirror"))
    private = bool(fs.getfirst("private"))

    auth_username = (fs.getfirst("auth_username") or "").strip()
    auth_password = (fs.getfirst("auth_password") or "").strip()
    auth_token = (fs.getfirst("auth_token") or "").strip()

    if not repo_owner or not repo_name or not clone_addr:
        render_error("Missing fields", "repo_owner, repo_name, and clone_addr are required.")
        return

    payload: Dict[str, Any] = {
        "clone_addr": clone_addr,
        "repo_name": repo_name,
        "repo_owner": repo_owner,
        "mirror": mirror,
        "private": private,
        "service": "git",
    }

    if auth_username:
        payload["auth_username"] = auth_username
    if auth_password:
        payload["auth_password"] = auth_password
    if auth_token:
        payload["auth_token"] = auth_token

    status, resp, raw = gitea_api("POST", "/repos/migrate", token, payload)

    if status not in (200, 201):
        # Show a sanitized error (avoid echoing secrets)
        safe_payload = dict(payload)
        if "auth_password" in safe_payload:
            safe_payload["auth_password"] = "***"
        if "auth_token" in safe_payload:
            safe_payload["auth_token"] = "***"
        render_error(
            "Migration failed",
            f"Gitea API returned HTTP {status}.",
            "Request payload:\n"
            + json.dumps(safe_payload, indent=2)
            + "\n\nResponse:\n"
            + (raw or json.dumps(resp, indent=2)),
        )
        return

    html_url = ""
    if isinstance(resp, dict):
        html_url = str(resp.get("html_url") or "")
        if not html_url:
            full_name = resp.get("full_name")
            if full_name:
                html_url = f"{_gitea_base().rstrip('/')}/{full_name}"

    if not html_url:
        html_url = _gitea_base()

    # 303 redirect to the created repo page
    print_headers("303 See Other", [("Location", html_url)])
    print(f"""<!doctype html>
<html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url={html_escape(html_url)}"></head>
<body>Redirecting to <a href="{html_escape(html_url)}">{html_escape(html_url)}</a>…</body></html>""")


def main() -> None:
    method = (os.environ.get("REQUEST_METHOD") or "GET").upper()

    if method == "POST":
        fs = cgi.FieldStorage()
        handle_submit(fs)
        return

    # GET
    qs = urllib.parse.parse_qs(os.environ.get("QUERY_STRING", ""), keep_blank_values=True)
    source_url = ""
    if "url" in qs and qs["url"]:
        source_url = qs["url"][0]
    render_form(source_url)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print_headers("500 Internal Server Error")
        print("<pre>")
        print(html_escape(repr(e)))
        print("</pre>")
