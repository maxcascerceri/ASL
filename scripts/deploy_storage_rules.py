#!/usr/bin/env python3
"""Deploy storage.rules to Firebase Storage without the Firebase CLI."""

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

import urllib.error
import urllib.request

RULES_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
API = "https://firebaserules.googleapis.com/v1"
DEFAULT_BUCKET = "asl-app-718bf.firebasestorage.app"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", default="asl-app-718bf")
    parser.add_argument(
        "--bucket",
        default=DEFAULT_BUCKET,
        help="Storage bucket (default: asl-app-718bf.firebasestorage.app)",
    )
    parser.add_argument(
        "--service-account",
        default=str(Path.home() / ".firebase-keys" / "asl-admin.json"),
    )
    parser.add_argument(
        "--rules-file",
        default=str(Path(__file__).resolve().parents[1] / "storage.rules"),
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
                "files": [{"name": "storage.rules", "content": rules_content}],
            }
        }
    ).encode("utf-8")

    ruleset_name = _post(f"{API}/projects/{project}/rulesets", ruleset_body, token)["name"]
    print(f"Created ruleset: {ruleset_name}")

    release_id = f"firebase.storage/{args.bucket}"
    release_body = json.dumps(
        {
            "release": {"name": f"projects/{project}/releases/{release_id}", "rulesetName": ruleset_name},
            "updateMask": "rulesetName",
        }
    ).encode("utf-8")

    _patch(f"{API}/projects/{project}/releases/{release_id}", release_body, token)
    print(f"Released rules to {release_id}")
    print("Done. Relaunch the app — Storage video reads should work again.")


def _post(url: str, body: bytes, token: str) -> dict:
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    return _read_json(req)


def _patch(url: str, body: bytes, token: str) -> dict:
    req = urllib.request.Request(
        url,
        data=body,
        method="PATCH",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
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
