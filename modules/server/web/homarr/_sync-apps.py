#!/usr/bin/env python3
import json
import os
import sqlite3
import sys
import time


def main():
    if len(sys.argv) < 3:
        print("Usage: sync-apps.py <db_path> <apps_json_path>")
        sys.exit(1)

    db_path = sys.argv[1]
    apps_json_path = sys.argv[2]

    for _ in range(20):
        if os.path.exists(db_path):
            break
        time.sleep(0.5)

    if not os.path.exists(db_path):
        print(f"[Homarr] Database {db_path} not found. Skipping declarative app synchronization.")
        sys.exit(0)


    with open(apps_json_path, "r", encoding="utf-8") as f:
        desired_apps = json.load(f)

    desired_ids = set(a["id"] for a in desired_apps)

    conn = sqlite3.connect(db_path, timeout=30)
    cursor = conn.cursor()

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='app'")
    if not cursor.fetchone():
        print("[Homarr] Table 'app' not found in database. Skipping.")
        conn.close()
        sys.exit(0)

    cursor.execute("SELECT id FROM app WHERE id LIKE 'declarative-%'")
    existing_ids = set(row[0] for row in cursor.fetchall())

    to_remove = existing_ids - desired_ids
    for app_id in to_remove:
        cursor.execute("DELETE FROM app WHERE id = ?", (app_id,))
        print(f"[Homarr] Removed declarative app: {app_id}")

    for app in desired_apps:
        cursor.execute(
            """
            INSERT INTO app (id, name, description, icon_url, href, ping_url)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                href = excluded.href,
                ping_url = excluded.ping_url
        """,
            (
                app["id"],
                app["name"],
                app.get("description", ""),
                app["icon_url"],
                app["href"],
                app.get("ping_url", ""),
            ),
        )
        if app["id"] not in existing_ids:
            print(f"[Homarr] Added declarative app: {app['name']} ({app['id']})")
        else:
            print(f"[Homarr] Synced declarative app: {app['name']} ({app['id']})")

    conn.commit()
    conn.close()


    print("[Homarr] Declarative app enforcement complete.")


if __name__ == "__main__":
    main()
