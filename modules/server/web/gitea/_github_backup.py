#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
_github_backup.py - Automatically mirrors GitHub repositories to a Gitea instance.

Features:
- Configurable via JSON config file or CLI flags.
- Supports GitHub user and organization targets.
- Filters by repository types: private, public, fork.
- Filters by repository names using glob or regex patterns.
- Ensures the target organization exists on Gitea (creates if absent).
- Creates Gitea git mirrors for new repositories (public without auth, private with GitHub PAT).
- Supports dry-run and mirror-sync modes.
"""

import argparse
import fnmatch
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional, Set, Tuple

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("gitea_github_backup")


def load_token(token_val: Optional[str], file_path: Optional[str], token_type: str) -> str:
    """Load a token from string or file, supporting shell exports and nix.conf format."""
    if token_val and token_val.strip():
        return token_val.strip()

    env_vars = {
        "github": ["GITHUB_TOKEN", "GH_TOKEN"],
        "gitea": ["GITEA_TOKEN", "GITEA_ADMIN_TOKEN", "TOKEN"],
    }
    for var in env_vars.get(token_type, []):
        val = os.environ.get(var)
        if val and val.strip():
            return val.strip()

    if not file_path:
        env_file_path = os.environ.get(f"{token_type.upper()}_TOKEN_FILE")
        if env_file_path:
            file_path = env_file_path

    if file_path and os.path.exists(file_path):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read().strip()
                for line in content.splitlines():
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if token_type == "github" and "github.com=" in line:
                        m = re.search(r"github\.com=([a-zA-Z0-9_]+)", line)
                        if m:
                            return m.group(1).strip()
                    if "=" in line:
                        k, v = line.split("=", 1)
                        k = k.removeprefix("export ").strip()
                        v = v.strip().strip("'\"")
                        if token_type == "gitea" and k in ("GITEA_TOKEN", "TOKEN", "GITEA_ADMIN_TOKEN"):
                            return v
                        if token_type == "github" and k in ("GITHUB_TOKEN", "GH_TOKEN", "TOKEN"):
                            return v
                lines = [l.strip() for l in content.splitlines() if l.strip() and not l.startswith("#")]
                if len(lines) == 1 and " " not in lines[0]:
                    return lines[0]
        except Exception as e:
            logger.warning(f"Could not read {token_type} token from {file_path}: {e}")

    return ""


def run_gitea_cli(cmd: List[str], env: Dict[str, str], timeout: int = 15) -> subprocess.CompletedProcess:
    """Run Gitea CLI command safely, dropping privileges to user 'gitea' if invoked as root."""
    kwargs: Dict[str, Any] = {
        "capture_output": True,
        "text": True,
        "timeout": timeout,
        "env": env,
    }
    if os.geteuid() == 0:
        try:
            import pwd
            pw = pwd.getpwnam("gitea")
            kwargs["user"] = pw.pw_uid
            kwargs["group"] = pw.pw_gid
            try:
                import grp
                gw = grp.getgrnam("web")
                kwargs["extra_groups"] = [gw.gr_gid]
            except Exception:
                pass
        except Exception:
            pass
    return subprocess.run(cmd, **kwargs)


def generate_gitea_token_from_cli(
    base_url: Optional[str] = None,
    gitea_bin: Optional[str] = None,
    gitea_config: Optional[str] = None,
    gitea_work_dir: Optional[str] = None,
    username: Optional[str] = None,
) -> str:
    """Use the local gitea CLI to generate an access token dynamically without pre-shared secrets."""
    bin_path = gitea_bin or shutil.which("gitea")
    if not bin_path or not os.path.exists(bin_path):
        return ""

    # Check cached token first
    token_cache_path = os.path.join(gitea_work_dir, "data", ".backup_api_token") if gitea_work_dir else None
    if token_cache_path and os.path.exists(token_cache_path):
        try:
            with open(token_cache_path, "r", encoding="utf-8") as f:
                cached = f.read().strip()
                if cached:
                    if base_url:
                        status, _, _ = gitea_api(base_url, "/user", cached)
                        if status == 200:
                            logger.info(f"Using valid cached Gitea API token from {token_cache_path}")
                            return cached
                        else:
                            logger.warning(f"Cached Gitea token is invalid (HTTP {status}). Regenerating...")
                            try:
                                os.remove(token_cache_path)
                            except Exception:
                                pass
                    else:
                        logger.debug(f"Using cached Gitea API token from {token_cache_path}")
                        return cached
        except Exception:
            pass

    env = dict(os.environ)
    if gitea_work_dir:
        env["GITEA_WORK_DIR"] = gitea_work_dir
        env["GITEA_CUSTOM"] = os.path.join(gitea_work_dir, "custom")
        env["HOME"] = gitea_work_dir
        env["USER"] = "gitea"

    cmd_base = [bin_path]
    if gitea_work_dir and os.path.exists(gitea_work_dir):
        cmd_base.extend(["--work-path", gitea_work_dir])
    if gitea_config and os.path.exists(gitea_config):
        cmd_base.extend(["--config", gitea_config])

    cmd_user = cmd_base + ["admin", "user"]

    # Discover users from Gitea CLI if username not explicitly given
    discovered_users: List[str] = []
    admin_users: List[str] = []
    try:
        res = run_gitea_cli(cmd_user + ["list"], env=env)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.strip().split()
                if len(parts) >= 2 and parts[0].isdigit():
                    uname = parts[1]
                    discovered_users.append(uname)
                    if len(parts) >= 5 and parts[4].lower() in ("true", "yes", "1"):
                        admin_users.append(uname)
            logger.info(f"Discovered existing Gitea users: {discovered_users} (admins: {admin_users})")
        else:
            logger.warning(
                f"Gitea admin user list returned code {res.returncode}:\n"
                f"Stdout: {res.stdout.strip()}\nStderr: {res.stderr.strip()}"
            )
    except Exception as e:
        logger.warning(f"Could not list users from Gitea CLI: {e}")

    # Determine candidate usernames to try generating token for
    candidate_usernames: List[str] = []
    if username:
        candidate_usernames.append(username)
    for a in admin_users:
        if a not in candidate_usernames:
            candidate_usernames.append(a)
    for name in ("cloudburst", "C10udburst", "c10udburst", "admin", "root"):
        match = next((u for u in discovered_users if u.lower() == name.lower()), None)
        if match and match not in candidate_usernames:
            candidate_usernames.append(match)
    for u in discovered_users:
        if u not in candidate_usernames:
            candidate_usernames.append(u)

    # If no users or no admins found, try creating dedicated admin user
    if not candidate_usernames:
        logger.info("No existing users found in Gitea. Creating dedicated admin user 'backup-admin'...")
        try:
            res_create = run_gitea_cli(
                cmd_user + [
                    "create",
                    "--username", "backup-admin",
                    "--email", "backup-admin@local",
                    "--random-password",
                    "--admin",
                    "--must-change-password=false",
                ],
                env=env,
            )
            if res_create.returncode == 0:
                logger.info("Created Gitea admin user 'backup-admin'.")
                candidate_usernames.insert(0, "backup-admin")
            else:
                logger.warning(f"Failed to create 'backup-admin': {res_create.stderr.strip()}")
        except Exception as e:
            logger.warning(f"Could not create backup-admin via Gitea CLI: {e}")

    # Try generating token for candidate users
    for user_to_try in candidate_usernames:
        token_name = f"gitea-backup-{int(time.time())}"
        try:
            res = run_gitea_cli(
                cmd_user + [
                    "generate-access-token",
                    "--username", user_to_try,
                    "--token-name", token_name,
                    "--scopes", "all",
                    "--raw",
                ],
                env=env,
            )
            if res.returncode == 0:
                token = res.stdout.strip()
                if token:
                    logger.info(f"Successfully generated Gitea API access token via Gitea CLI for user '{user_to_try}'.")
                    if token_cache_path:
                        try:
                            os.makedirs(os.path.dirname(token_cache_path), exist_ok=True)
                            with open(token_cache_path, "w", encoding="utf-8") as f:
                                f.write(token)
                            os.chmod(token_cache_path, 0o600)
                        except Exception as e:
                            logger.debug(f"Could not cache token to file: {e}")
                    return token
            else:
                logger.warning(
                    f"generate-access-token for '{user_to_try}' failed (code {res.returncode}): {res.stderr.strip()}"
                )
        except Exception as e:
            logger.warning(f"Failed to run generate-access-token for '{user_to_try}': {e}")

    return ""


def http_request(
    url: str,
    method: str = "GET",
    headers: Optional[Dict[str, str]] = None,
    body: Optional[Dict[str, Any]] = None,
    timeout: int = 30,
) -> Tuple[int, Any, str]:
    """Perform HTTP request returning (status_code, json_or_none, raw_text)."""
    req_headers = {"Accept": "application/json"}
    if headers:
        req_headers.update(headers)

    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        req_headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url=url, method=method.upper(), headers=req_headers, data=data)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "replace")
            status = resp.status
            parsed = None
            if raw.strip():
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None
            return status, parsed, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace") if e.fp else ""
        parsed = None
        if raw.strip():
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                parsed = None
        return e.code, parsed, raw
    except Exception as e:
        return 0, None, str(e)


# ─────────────────────────────────────────────────────────────────────────────
# GitHub API
# ─────────────────────────────────────────────────────────────────────────────

def github_api(
    endpoint: str,
    token: Optional[str] = None,
    method: str = "GET",
    params: Optional[Dict[str, Any]] = None,
) -> Tuple[int, Any, str]:
    base_url = "https://api.github.com"
    url = f"{base_url}{endpoint}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "gitea-github-backup",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    return http_request(url, method=method, headers=headers)


def get_authenticated_github_user(token: Optional[str]) -> Optional[str]:
    if not token:
        return None
    status, data, _ = github_api("/user", token=token)
    if status == 200 and isinstance(data, dict):
        return data.get("login")
    return None


def fetch_github_repos(target_user: str, token: Optional[str]) -> List[Dict[str, Any]]:
    auth_user = get_authenticated_github_user(token)
    is_auth_user = auth_user and auth_user.lower() == target_user.lower()

    repos: List[Dict[str, Any]] = []
    page = 1
    per_page = 100

    endpoint = None
    params_base: Dict[str, Any] = {"per_page": per_page}

    if is_auth_user:
        endpoint = "/user/repos"
        params_base["affiliation"] = "owner"
    else:
        # Check if organization or user
        status_org, _, _ = github_api(f"/orgs/{target_user}", token=token)
        if status_org == 200:
            endpoint = f"/orgs/{target_user}/repos"
            params_base["type"] = "all"
        else:
            endpoint = f"/users/{target_user}/repos"
            params_base["type"] = "all"

    logger.info(f"Fetching GitHub repositories for '{target_user}' using {endpoint}...")

    while True:
        params = dict(params_base)
        params["page"] = page
        status, data, raw = github_api(endpoint, token=token, params=params)

        if status == 403 and "rate limit" in raw.lower():
            logger.error(f"GitHub API rate limit exceeded while querying '{target_user}'.")
            break
        if status != 200:
            logger.error(f"Failed to fetch repositories from GitHub ({status}): {raw}")
            break

        if not isinstance(data, list) or not data:
            break

        repos.extend(data)
        if len(data) < per_page:
            break
        page += 1

    logger.info(f"Found {len(repos)} total repositories on GitHub for '{target_user}'.")
    return repos


# ─────────────────────────────────────────────────────────────────────────────
# Filtering
# ─────────────────────────────────────────────────────────────────────────────

def matches_types(repo: Dict[str, Any], allowed_types: List[str]) -> bool:
    allowed: Set[str] = {t.lower() for t in allowed_types}
    is_private = bool(repo.get("private", False))
    is_fork = bool(repo.get("fork", False))

    if allowed == {"fork"}:
        return is_fork

    if is_private and "private" not in allowed:
        return False
    if not is_private and "public" not in allowed:
        return False

    if is_fork and "fork" not in allowed:
        return False

    return True


def matches_filter(name: str, filters: List[str]) -> bool:
    if not filters:
        return True
    for pattern in filters:
        if pattern == "*":
            return True
        if fnmatch.fnmatch(name, pattern):
            return True
    return False


# ─────────────────────────────────────────────────────────────────────────────
# Gitea API
# ─────────────────────────────────────────────────────────────────────────────

def gitea_api(
    base_url: str,
    path: str,
    token: str,
    method: str = "GET",
    body: Optional[Dict[str, Any]] = None,
) -> Tuple[int, Any, str]:
    url = f"{base_url.rstrip('/')}/api/v1{path}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/json",
    }
    return http_request(url, method=method, headers=headers, body=body)


def ensure_gitea_owner(
    base_url: str,
    token: str,
    name: str,
    dry_run: bool = False,
    cli_fallback: Optional[Dict[str, Any]] = None,
) -> Tuple[bool, str, str]:
    """Ensure target owner exists on Gitea (user or org). Returns (success, token, canonical_name)."""
    # 1. Check if user exists
    status, user_data, _ = gitea_api(base_url, f"/users/{name}", token)
    if status == 200 and isinstance(user_data, dict):
        canonical_name = user_data.get("username", name)
        logger.debug(f"Gitea user '{canonical_name}' exists.")
        return True, token, canonical_name

    # 2. Check if organization exists
    status, org_data, _ = gitea_api(base_url, f"/orgs/{name}", token)
    if status == 200 and isinstance(org_data, dict):
        canonical_name = org_data.get("username", name)
        logger.debug(f"Gitea organization '{canonical_name}' exists.")
        return True, token, canonical_name

    # 3. Create organization
    logger.info(f"Neither user nor org '{name}' found on Gitea. Creating Gitea organization...")
    if dry_run:
        logger.info(f"[DRY-RUN] Would create Gitea organization '{name}'.")
        return True, token, name

    payload = {
        "username": name,
        "full_name": name,
        "visibility": "public",
        "description": f"Automated backup mirror organization for GitHub {name}",
    }
    status, resp, raw = gitea_api(base_url, "/orgs", token, method="POST", body=payload)
    if status in (200, 201):
        logger.info(f"Successfully created Gitea organization '{name}'.")
        return True, token, name
    elif status == 422:
        logger.warning(f"Creating org '{name}' returned 422 (it may already exist): {raw}")
        return True, token, name
    elif status == 403 and cli_fallback and (cli_fallback.get("bin") or cli_fallback.get("config")):
        logger.warning(
            f"Token lacks write:organization permission to create '{name}'. Generating full admin token via Gitea CLI..."
        )
        cache_path = os.path.join(cli_fallback.get("work_dir") or "", "data", ".backup_api_token")
        if os.path.exists(cache_path):
            try:
                os.remove(cache_path)
            except Exception:
                pass
        new_token = generate_gitea_token_from_cli(
            base_url=base_url,
            gitea_bin=cli_fallback.get("bin"),
            gitea_config=cli_fallback.get("config"),
            gitea_work_dir=cli_fallback.get("work_dir"),
            username=cli_fallback.get("user"),
        )
        if new_token:
            status_r, _, raw_r = gitea_api(base_url, "/orgs", new_token, method="POST", body=payload)
            if status_r in (200, 201):
                logger.info(f"Successfully created Gitea organization '{name}' using CLI-generated token.")
                return True, new_token, name
            elif status_r == 422:
                return True, new_token, name
            else:
                logger.error(f"Failed to create Gitea organization '{name}' with CLI token ({status_r}): {raw_r}")
                return False, new_token, name
        return False, token, name
    else:
        logger.error(f"Failed to create Gitea organization '{name}' ({status}): {raw}")
        return False, token, name


def repo_exists_in_gitea(base_url: str, token: str, owner: str, repo_name: str) -> bool:
    status, _, _ = gitea_api(base_url, f"/repos/{owner}/{repo_name}", token)
    return status == 200


def create_gitea_mirror(
    base_url: str,
    gitea_token: str,
    owner: str,
    repo: Dict[str, Any],
    github_token: Optional[str] = None,
    dry_run: bool = False,
    cli_fallback: Optional[Dict[str, Any]] = None,
) -> Tuple[bool, str]:
    repo_name = repo["name"]
    clone_url = repo.get("clone_url")
    is_private = bool(repo.get("private", False))

    if not clone_url:
        logger.error(f"No clone_url found for repository {repo_name}")
        return False, gitea_token

    payload: Dict[str, Any] = {
        "clone_addr": clone_url,
        "repo_name": repo_name,
        "repo_owner": owner,
        "mirror": True,
        "private": is_private,
        "service": "git",
        "description": repo.get("description") or "",
    }

    # Authentication rule:
    # If public, add no auth. If private, use GitHub PAT token as auth.
    if is_private:
        if not github_token:
            logger.error(
                f"Repository '{owner}/{repo_name}' is private, but no GitHub token was provided for authentication!"
            )
            return False, gitea_token
        payload["auth_token"] = github_token

    if dry_run:
        logger.info(
            f"[DRY-RUN] Would create Gitea mirror for {owner}/{repo_name} (private={is_private}, auth={'yes' if is_private else 'no'})"
        )
        return True, gitea_token

    status, resp, raw = gitea_api(base_url, "/repos/migrate", gitea_token, method="POST", body=payload)
    if status in (200, 201):
        logger.info(f"[CREATED] Successfully set up mirror for {owner}/{repo_name}")
        return True, gitea_token
    elif status == 409:
        logger.info(f"[EXISTS] Repo {owner}/{repo_name} already exists in Gitea.")
        return True, gitea_token
    elif status == 403 and cli_fallback and (cli_fallback.get("bin") or cli_fallback.get("config")):
        logger.warning(f"Mirror creation failed with 403. Generating fresh token via Gitea CLI...")
        new_token = generate_gitea_token_from_cli(
            base_url=base_url,
            gitea_bin=cli_fallback.get("bin"),
            gitea_config=cli_fallback.get("config"),
            gitea_work_dir=cli_fallback.get("work_dir"),
            username=cli_fallback.get("user"),
        )
        if new_token:
            status_r, _, raw_r = gitea_api(base_url, "/repos/migrate", new_token, method="POST", body=payload)
            if status_r in (200, 201):
                logger.info(f"[CREATED] Successfully set up mirror for {owner}/{repo_name} using CLI token.")
                return True, new_token
            elif status_r == 409:
                return True, new_token
            else:
                logger.error(f"Failed to migrate repository {owner}/{repo_name} with CLI token ({status_r}): {raw_r}")
                return False, new_token
        return False, gitea_token
    else:
        logger.error(f"Failed to migrate repository {owner}/{repo_name} ({status}): {raw}")
        return False, gitea_token


# ─────────────────────────────────────────────────────────────────────────────
# Config Normalization
# ─────────────────────────────────────────────────────────────────────────────

def parse_targets(config_data: Any) -> List[Dict[str, Any]]:
    raw_list: List[Dict[str, Any]] = []

    if isinstance(config_data, list):
        raw_list = config_data
    elif isinstance(config_data, dict):
        if "targets" in config_data and isinstance(config_data["targets"], list):
            raw_list = config_data["targets"]
        elif "user" in config_data:
            raw_list = [config_data]
        else:
            for k, v in config_data.items():
                if isinstance(v, dict):
                    t = dict(v)
                    if "user" not in t:
                        t["user"] = k
                    raw_list.append(t)
                else:
                    raw_list.append({"user": k})
    else:
        raise ValueError("Configuration must be a list or object")

    targets: List[Dict[str, Any]] = []
    for item in raw_list:
        if not isinstance(item, dict) or not item.get("user"):
            continue
        user = str(item["user"]).strip()
        types = item.get("types", ["private", "public", "fork"])
        if isinstance(types, str):
            types = [types]

        filters = item.get("filter", item.get("filters", ["*"]))
        if isinstance(filters, str):
            filters = [filters]

        targets.append({
            "user": user,
            "types": list(types),
            "filter": list(filters),
        })

    return targets


# ─────────────────────────────────────────────────────────────────────────────
# Main Routine
# ─────────────────────────────────────────────────────────────────────────────

def process_target(
    target: Dict[str, Any],
    base_url: str,
    gitea_token: str,
    github_token: Optional[str],
    dry_run: bool = False,
    cli_fallback: Optional[Dict[str, Any]] = None,
) -> str:
    user = target["user"]
    allowed_types = target["types"]
    filters = target["filter"]

    logger.info("=" * 60)
    logger.info(f"Processing backup target: '{user}'")
    logger.info(f"  Allowed types: {allowed_types}")
    logger.info(f"  Name filter(s): {filters}")
    logger.info("=" * 60)

    # 1. Ensure target owner exists on Gitea
    ok, gitea_token, canonical_owner = ensure_gitea_owner(
        base_url, gitea_token, user, dry_run=dry_run, cli_fallback=cli_fallback
    )
    if not ok:
        logger.error(f"Could not verify or create Gitea organization '{user}'. Skipping target.")
        return gitea_token

    # 2. Fetch all repos from GitHub
    all_repos = fetch_github_repos(user, github_token)

    # 3. Filter repos
    matched_repos = []
    for repo in all_repos:
        name = repo["name"]
        if not matches_types(repo, allowed_types):
            logger.debug(f"Skipping '{name}': does not match allowed types {allowed_types}")
            continue
        if not matches_filter(name, filters):
            logger.debug(f"Skipping '{name}': does not match filter {filters}")
            continue
        matched_repos.append(repo)

    logger.info(f"Matched {len(matched_repos)} / {len(all_repos)} repositories for target '{user}'.")

    # 4. Process each repository
    for repo in matched_repos:
        repo_name = repo["name"]

        if repo_exists_in_gitea(base_url, gitea_token, canonical_owner, repo_name):
            logger.info(f"[EXISTS] {canonical_owner}/{repo_name} already exists in Gitea, skipping.")
            continue

        _, gitea_token = create_gitea_mirror(
            base_url=base_url,
            gitea_token=gitea_token,
            owner=canonical_owner,
            repo=repo,
            github_token=github_token,
            dry_run=dry_run,
            cli_fallback=cli_fallback,
        )

    return gitea_token


def main() -> None:
    parser = argparse.ArgumentParser(description="Backup GitHub repositories to Gitea as mirrors.")
    parser.add_argument("--config", "-c", help="Path to JSON configuration file.")
    parser.add_argument("--user", "-u", help="GitHub username or organization name.")
    parser.add_argument(
        "--types",
        default="private,public,fork",
        help="Comma-separated repository types to include (default: private,public,fork).",
    )
    parser.add_argument(
        "--filter",
        default="*",
        help="Glob pattern to filter repositories (default: *).",
    )
    parser.add_argument("--gitea-url", default=os.environ.get("GITEA_BASE_URL", "http://127.0.0.1:3000"))
    parser.add_argument("--gitea-token", default=None, help="Gitea API token.")
    parser.add_argument("--gitea-token-file", default=None, help="Path to file containing Gitea token.")
    parser.add_argument("--gitea-bin", default=None, help="Path to gitea binary for CLI operations.")
    parser.add_argument("--gitea-config", default=None, help="Path to gitea app.ini configuration file.")
    parser.add_argument("--gitea-work-dir", default=None, help="Path to gitea state directory.")
    parser.add_argument("--admin-user", default=None, help="Gitea admin user for CLI token generation.")
    parser.add_argument("--github-token", default=None, help="GitHub Personal Access Token.")
    parser.add_argument("--github-token-file", default=None, help="Path to file containing GitHub token.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate actions without modifying Gitea.")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose debug logging.")

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    cli_fallback = {
        "bin": args.gitea_bin,
        "config": args.gitea_config,
        "work_dir": args.gitea_work_dir,
        "user": args.admin_user,
    }

    # Load tokens
    gitea_token = load_token(args.gitea_token, args.gitea_token_file, "gitea")
    github_token = load_token(args.github_token, args.github_token_file, "github")

    if not gitea_token and not args.dry_run:
        # Fall back to generating an access token using Gitea CLI directly
        gitea_token = generate_gitea_token_from_cli(
            base_url=args.gitea_url,
            gitea_bin=args.gitea_bin,
            gitea_config=args.gitea_config,
            gitea_work_dir=args.gitea_work_dir,
            username=args.admin_user,
        )

    if not gitea_token and not args.dry_run:
        logger.error(
            "Gitea token is required! Provide via --gitea-token, --gitea-token-file, GITEA_TOKEN, or via --gitea-bin / --gitea-config CLI access."
        )
        sys.exit(1)

    # Load targets
    targets: List[Dict[str, Any]] = []
    if args.config:
        try:
            with open(args.config, "r", encoding="utf-8") as f:
                data = json.load(f)
                targets = parse_targets(data)
        except Exception as e:
            logger.error(f"Failed to read configuration file '{args.config}': {e}")
            sys.exit(1)
    elif args.user:
        types_list = [t.strip() for t in args.types.split(",") if t.strip()]
        targets = [{
            "user": args.user,
            "types": types_list,
            "filter": [args.filter],
        }]
    else:
        logger.error("No targets specified. Use --config <file> or --user <name>.")
        sys.exit(1)

    if not targets:
        logger.warning("No valid backup targets found in configuration.")
        return

    logger.info(f"Starting GitHub to Gitea backup for {len(targets)} target(s)...")
    if args.dry_run:
        logger.info("[DRY-RUN MODE ACTIVATED] No changes will be made.")

    for target in targets:
        try:
            gitea_token = process_target(
                target=target,
                base_url=args.gitea_url,
                gitea_token=gitea_token,
                github_token=github_token,
                dry_run=args.dry_run,
                cli_fallback=cli_fallback,
            )
        except Exception as e:
            logger.error(f"Unexpected error processing target '{target.get('user')}': {e}", exc_info=True)

    logger.info("Backup job finished.")


if __name__ == "__main__":
    main()
