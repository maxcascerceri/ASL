#!/usr/bin/env python3
"""Merge posterStoragePath into Firestore words/{id} for filmed signs in Storage."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore, storage

DEFAULT_BUCKET = "asl-app-718bf.firebasestorage.app"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", default="asl-app-718bf")
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument(
        "--service-account",
        default=str(Path.home() / ".firebase-keys" / "asl-admin.json"),
    )
    parser.add_argument("--prefix", default="asl-videos/")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Max words to update (0 = all).")
    return parser.parse_args()


def poster_path_for(video_storage_path: str) -> str:
    parts = video_storage_path.split("/")
    if len(parts) < 3:
        raise ValueError(f"Unexpected storage path: {video_storage_path}")
    parts[-1] = "poster_001.jpg"
    return "/".join(parts)


def word_id_from_video_path(storage_path: str) -> str | None:
    # asl-videos/thankyou/video_001.mov
    parts = storage_path.split("/")
    if len(parts) < 3 or parts[0] != "asl-videos":
        return None
    return parts[1]


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
    db = firestore.client()

    word_to_poster: dict[str, str] = {}
    for blob in bucket.list_blobs(prefix=args.prefix):
        name = blob.name
        if not name.endswith((".mov", ".mp4", ".m4v")):
            continue
        if "/video_" not in name:
            continue
        word_id = word_id_from_video_path(name)
        if not word_id:
            continue
        poster_path = poster_path_for(name)
        if not bucket.blob(poster_path).exists():
            continue
        word_to_poster[word_id] = poster_path

    updated = 0
    skipped = 0
    failed = 0
    processed = 0

    for word_id, poster_path in sorted(word_to_poster.items()):
        processed += 1
        if args.limit and updated + skipped + failed >= args.limit:
            break

        ref = db.collection("words").document(word_id)
        try:
            snap = ref.get()
            if snap.exists:
                existing = (snap.to_dict() or {}).get("posterStoragePath")
                if existing == poster_path:
                    skipped += 1
                    continue

            if args.dry_run:
                print(f"would merge words/{word_id} posterStoragePath={poster_path}")
                updated += 1
                continue

            ref.set({"posterStoragePath": poster_path}, merge=True)
            updated += 1
            if updated % 50 == 0:
                print(f"Updated {updated} word docs…")
        except Exception as exc:
            print(f"Failed words/{word_id}: {exc}", file=sys.stderr)
            failed += 1

    print(
        json.dumps(
            {
                "projectId": args.project_id,
                "filmedWithPoster": len(word_to_poster),
                "processed": processed,
                "updated": updated,
                "skippedExisting": skipped,
                "failed": failed,
                "dryRun": args.dry_run,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
