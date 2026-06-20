#!/usr/bin/env python3
"""Upload mobile H.264 MP4 variants to Firebase Storage alongside existing MOV files."""

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
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ASL" / "BundledMedia" / "Videos",
    )
    parser.add_argument("--project-id", default="asl-app-718bf")
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument(
        "--service-account",
        default=str(Path.home() / ".firebase-keys" / "asl-admin.json"),
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.source_dir.exists():
        print(f"Missing source dir: {args.source_dir}", file=sys.stderr)
        raise SystemExit(1)

    mp4_files = sorted(args.source_dir.glob("*.mp4"))
    if not mp4_files:
        print("No MP4 files to upload.", file=sys.stderr)
        raise SystemExit(1)

    if args.dry_run:
        for path in mp4_files[:10]:
            word_id = path.stem
            print(f"would upload {word_id} -> asl-videos/{word_id}/video_001.mp4")
        print(f"... total {len(mp4_files)}")
        return

    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred, {"storageBucket": args.bucket})
    bucket = storage.bucket()

    uploaded = 0
    for path in mp4_files:
        word_id = path.stem
        storage_path = f"asl-videos/{word_id}/video_001.mp4"
        blob = bucket.blob(storage_path)
        if blob.exists():
            continue
        blob.cache_control = "public, max-age=86400"
        blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
        blob.upload_from_filename(str(path), content_type="video/mp4")
        uploaded += 1
        if uploaded % 25 == 0:
            print(f"Uploaded {uploaded} mobile videos…")

    print(json.dumps({"uploaded": uploaded, "scanned": len(mp4_files)}, indent=2))


if __name__ == "__main__":
    main()
