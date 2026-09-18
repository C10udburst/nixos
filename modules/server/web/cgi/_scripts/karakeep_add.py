#!/usr/bin/env python3
import os
import json
import re
import time
import cgi
import urllib.request
import urllib.error
from urllib.parse import urlparse

KARAKEEP_WAKE_URL = os.environ.get("KARAKEEP_WAKE_URL", "https://bookmarks.brix0.wilkins.pl.eu.org")
KARAKEEP_BASE = os.environ.get("KARAKEEP_BASE", "http://localhost:3080").rstrip("/")
KARAKEEP_API_KEY = os.environ.get("KARAKEEP_API_KEY", "")
# Optional: shared secret to prevent random abuse of your CGI endpoint
CGI_TOKEN = os.environ.get("KARAKEEP_CGI_TOKEN", "")  # if set, require ?token=...

API_CREATE_BOOKMARK = f"{KARAKEEP_BASE}/api/v1/bookmarks"
REDIRECT_AFTER = os.environ.get("KARAKEEP_REDIRECT_AFTER", f"{KARAKEEP_WAKE_URL}/")  # where the user ends up after saving

def respond(status_line: str, headers: dict, body: str = ""):
    print(status_line)
    for k, v in headers.items():
        print(f"{k}: {v}")
    print()
    if body:
        print(body)


def is_reasonable_http_url(u: str) -> bool:
    if not u or len(u) > 4000:
        return False
    p = urlparse(u)
    if p.scheme not in ("http", "https"):
        return False
    if not p.netloc:
        return False
    # basic sanity: avoid whitespace/control chars
    if re.search(r"[\x00-\x20]", u):
        return False
    return True


def main():
    form = cgi.FieldStorage()
    url = (form.getfirst("url") or "").strip()
    token = (form.getfirst("token") or "").strip()
    
    for _ in range(30):
        try:
            req = urllib.request.urlopen(KARAKEEP_WAKE_URL, timeout=5)
            powered_by = req.headers.get("X-Powered-By", "")
            if powered_by != "ContainerNursery":
                break
        except Exception:
            pass
        time.sleep(0.25)

    if CGI_TOKEN and token != CGI_TOKEN:
        respond(
            "Status: 403 Forbidden",
            {"Content-Type": "text/plain; charset=utf-8"},
            "Forbidden",
        )
        return

    if not is_reasonable_http_url(url):
        respond(
            "Status: 400 Bad Request",
            {"Content-Type": "text/plain; charset=utf-8"},
            "Bad Request: provide a valid http(s) URL via ?url=",
        )
        return

    if not KARAKEEP_API_KEY:
        respond(
            "Status: 500 Internal Server Error",
            {"Content-Type": "text/plain; charset=utf-8"},
            "Server not configured: set KARAKEEP_API_KEY env var",
        )
        return

    payload = json.dumps({"type": "link", "url": url}).encode("utf-8")
    req = urllib.request.Request(
        API_CREATE_BOOKMARK,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {KARAKEEP_API_KEY}",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            # Accept 200/201 as success (docs list 200/201 patterns for create endpoints)
            if resp.status not in (200, 201):
                raise urllib.error.HTTPError(
                    req.full_url, resp.status, resp.reason, resp.headers, None
                )
    except urllib.error.HTTPError as e:
        # If bookmark already exists, Karakeep may respond with 200 in some cases; treat other codes as error.
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        respond(
            "Status: 502 Bad Gateway",
            {"Content-Type": "text/plain; charset=utf-8"},
            f"Karakeep API error ({e.code}): {body or e.reason}",
        )
        return
    except Exception as e:
        respond(
            "Status: 502 Bad Gateway",
            {"Content-Type": "text/plain; charset=utf-8"},
            f"Request failed: {e}",
        )
        return

    # Success: redirect user to Karakeep UI
    respond(
        "Status: 302 Found",
        {"Location": REDIRECT_AFTER, "Content-Type": "text/plain; charset=utf-8"},
        "Redirecting…",
    )


if __name__ == "__main__":
    main()
