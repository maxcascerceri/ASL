#!/usr/bin/env python3
"""Add firebaseStorageDownloadTokens to Storage blobs missing them.

The iOS Firebase Storage SDK's downloadURL() expects this metadata field.
Admin SDK uploads often omit it; public read rules still allow tokenless ?alt=media
URLs, but downloadURL() can fail without tokens.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, storage

DEFAULT_BUCKET = "asl-app-718bf.firebasestorage.app"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", default="asl-app-718bf")
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument(
        "--service-account",
        default=str(Path.home() / ".firebase-keys" / "asl-admin.json"),
    )
    parser.add_argument(
        "--prefix",
        default="asl-videos/",
        help="Only patch blobs under this prefix.",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    sa_path = Path(args.service_account).expanduser()
    if not sa_path.is_file():
        print(f"Missing service account: {sa_path}", file=sys.stderr)
        raise SystemExit(1)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(
            credentials.Certificate(str(sa_path)),
            {"projectId": args.project_id, "storageBucket": args.bucket},
        )

    bucket = storage.bucket()
    patched = 0
    skipped = 0
    total = 0

    for blob in bucket.list_blobs(prefix=args.prefix):
        total += 1
        blob.reload()
        metadata = blob.metadata or {}
        if metadata.get("firebaseStorageDownloadTokens"):
            skipped += 1
            continue

        token = str(uuid.uuid4())
        if args.dry_run:
            print(f"would patch: {blob.name}")
            patched += 1
            continue

        metadata = dict(metadata)
        metadata["firebaseStorageDownloadTokens"] = token
        blob.metadata = metadata
        blob.patch()
        patched += 1
        if patched % 50 == 0:
            print(f"Patched {patched}…")

    print(
        json.dumps(
            {
                "bucket": args.bucket,
                "prefix": args.prefix,
                "total": total,
                "patched": patched,
                "alreadyHadToken": skipped,
                "dryRun": args.dry_run,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
