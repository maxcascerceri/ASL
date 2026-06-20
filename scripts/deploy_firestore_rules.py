#!/usr/bin/env python3
"""Deploy firestore.rules to Firebase without the Firebase CLI."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import google.auth.transport.requests
    from google.oauth2 import service_account
except ImportError:
    print("Install: pip install google-auth", file=sys.stderr)
    raise SystemExit(1)

try:
    import urllib.request
except ImportError:
    raise SystemExit(1)

RULES_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
API = "https://firebaserules.googleapis.com/v1"


def main() -> None:
    parser = argparse.ArgumentParser(description="Deploy Firestore security rules.")
    parser.add_argument("--project-id", default="asl-app-718bf")
    parser.add_argument(
        "--service-account",
        default=str(Path.home() / ".firebase-keys" / "asl-admin.json"),
        help="Path to Firebase service account JSON",
    )
    parser.add_argument(
        "--rules-file",
        default=str(Path(__file__).resolve().parents[1] / "firestore.rules"),
    )
    args = parser.parse_args()

    rules_path = Path(args.rules_file)
    if not rules_path.is_file():
        print(f"Missing rules file: {rules_path}", file=sys.stderr)
        raise SystemExit(1)

    sa_path = Path(args.service_account).expanduser()
    if not sa_path.is_file():
        print(f"Missing service account: {sa_path}", file=sys.stderr)
        raise SystemExit(1)

    rules_content = rules_path.read_text(encoding="utf-8")
    credentials = service_account.Credentials.from_service_account_file(
        str(sa_path), scopes=[RULES_SCOPE]
    )
    credentials.refresh(google.auth.transport.requests.Request())
    token = credentials.token

    project = args.project_id
    ruleset_body = json.dumps(
        {
            "source": {
                "files": [
                    {"name": "firestore.rules", "content": rules_content},
                ]
            }
        }
    ).encode("utf-8")

    ruleset_name = _post(
        f"{API}/projects/{project}/rulesets",
        ruleset_body,
        token,
    )["name"]
    print(f"Created ruleset: {ruleset_name}")

    release_name = f"projects/{project}/releases/cloud.firestore"
    release_body = json.dumps(
        {
            "release": {
                "name": release_name,
                "rulesetName": ruleset_name,
            },
            "updateMask": "rulesetName",
        }
    ).encode("utf-8")

    # Release id is literally `cloud.firestore` (Firestore rules target).
    _patch(f"{API}/projects/{project}/releases/cloud.firestore", release_body, token)
    print(f"Released rules to cloud.firestore for {project}")
    print("Done. Relaunch the app — paths/words/videos reads should succeed.")


def _post(url: str, body: bytes, token: str) -> dict:
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    return _read_json(req)


def _patch(url: str, body: bytes, token: str) -> dict:
    req = urllib.request.Request(
        url,
        data=body,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    return _read_json(req)


def _read_json(req: urllib.request.Request) -> dict:
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP {exc.code}: {detail}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
