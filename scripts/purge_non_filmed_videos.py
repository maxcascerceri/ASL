#!/usr/bin/env python3
"""Remove legacy Firebase videos not covered by filmmaker upload manifests.

Deletes Storage blobs and Firestore ``words/{id}/videos/*`` for word IDs outside
the keep allowlist. Preserves parent ``words/{id}`` docs (sets ``videoCount: 0``)
and does not touch ``paths/`` curriculum.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MANIFESTS = (
    SCRIPT_DIR / "elijah_videos.json",
    SCRIPT_DIR / "victoria_ariel_videos.json",
)
DEFAULT_LOG = SCRIPT_DIR / "purge_non_filmed_videos_log.json"
STORAGE_PREFIX = "asl-videos/"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--keep-manifest",
        type=Path,
        action="append",
        default=None,
        help="Filmed-video manifest JSON (repeatable). Defaults to Elijah + Victoria/Ariel.",
    )
    parser.add_argument("--project-id", required=True, help="Firebase project ID.")
    parser.add_argument(
        "--bucket",
        required=True,
        help="Firebase Storage bucket, e.g. asl-app-718bf.firebasestorage.app.",
    )
    parser.add_argument("--service-account", type=Path, help="Firebase service account JSON.")
    parser.add_argument(
        "--log",
        type=Path,
        default=DEFAULT_LOG,
        help=f"Audit log path (default: {DEFAULT_LOG.name}).",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="Report planned deletes only.")
    mode.add_argument("--execute", action="store_true", help="Perform deletes.")
    return parser.parse_args()


def load_keep_word_ids(manifest_paths: list[Path]) -> set[str]:
    keep: set[str] = set()
    for path in manifest_paths:
        if not path.exists():
            raise SystemExit(f"Keep manifest not found: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        videos = data.get("videos", [])
        if not videos:
            raise SystemExit(f"No videos in manifest: {path}")
        for entry in videos:
            word_id = entry.get("wordId", "").strip()
            if word_id:
                keep.add(word_id)
    return keep


def initialize_firebase(project_id: str, bucket: str, service_account: Path | None):
    import firebase_admin
    from firebase_admin import credentials, firestore, storage

    if firebase_admin._apps:
        return firestore.client(), storage.bucket()

    if service_account:
        credential = credentials.Certificate(service_account)
    else:
        credential = credentials.ApplicationDefault()

    firebase_admin.initialize_app(
        credential,
        {"projectId": project_id, "storageBucket": bucket},
    )
    return firestore.client(), storage.bucket()


def word_id_from_blob_name(blob_name: str) -> str | None:
    if not blob_name.startswith(STORAGE_PREFIX):
        return None
    remainder = blob_name[len(STORAGE_PREFIX) :]
    parts = remainder.split("/")
    if len(parts) >= 2 and parts[0]:
        return parts[0]
    return None


def collect_storage_word_ids(bucket) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {}
    for blob in bucket.list_blobs(prefix=STORAGE_PREFIX):
        word_id = word_id_from_blob_name(blob.name)
        if not word_id:
            continue
        grouped.setdefault(word_id, []).append(blob.name)
    return grouped


def collect_firestore_video_word_ids(db) -> dict[str, list[str]]:
    """Map wordId -> video doc IDs via collection group (one pass, not N+1)."""
    grouped: dict[str, list[str]] = {}
    for video_snap in db.collection_group("videos").stream():
        word_doc = video_snap.reference.parent.parent
        word_id = word_doc.id
        grouped.setdefault(word_id, []).append(video_snap.id)
    return grouped


def batch_delete_storage(bucket, paths: list[str], batch_size: int = 200) -> int:
    deleted = 0
    for start in range(0, len(paths), batch_size):
        chunk = paths[start : start + batch_size]
        bucket.delete_blobs(chunk)
        deleted += len(chunk)
        print(f"  Storage: deleted {deleted}/{len(paths)} blobs", flush=True)
    return deleted


def batch_delete_firestore_videos(db, firestore_by_word: dict[str, list[str]], word_ids: list[str]) -> int:
    deleted = 0
    batch = db.batch()
    ops = 0
    for word_id in word_ids:
        for video_id in firestore_by_word.get(word_id, []):
            ref = db.collection("words").document(word_id).collection("videos").document(video_id)
            batch.delete(ref)
            ops += 1
            deleted += 1
            if ops >= 450:
                batch.commit()
                print(f"  Firestore videos: deleted {deleted} docs", flush=True)
                batch = db.batch()
                ops = 0
    if ops:
        batch.commit()
    print(f"  Firestore videos: deleted {deleted} docs (done)", flush=True)
    return deleted


def batch_reset_word_parents(db, word_ids: list[str]) -> int:
    reset = 0
    batch = db.batch()
    ops = 0
    for word_id in word_ids:
        ref = db.collection("words").document(word_id)
        batch.set(ref, {"videoCount": 0}, merge=True)
        ops += 1
        reset += 1
        if ops >= 450:
            batch.commit()
            print(f"  Parent words reset: {reset}/{len(word_ids)}", flush=True)
            batch = db.batch()
            ops = 0
    if ops:
        batch.commit()
    print(f"  Parent words reset: {reset}/{len(word_ids)} (done)", flush=True)
    return reset


def main() -> None:
    args = parse_args()
    manifest_paths = args.keep_manifest or list(DEFAULT_MANIFESTS)
    keep_ids = load_keep_word_ids(manifest_paths)

    db, bucket = initialize_firebase(args.project_id, args.bucket, args.service_account)
    storage_by_word = collect_storage_word_ids(bucket)
    firestore_by_word = collect_firestore_video_word_ids(db)

    all_seen = set(storage_by_word) | set(firestore_by_word)
    purge_ids = sorted(wid for wid in all_seen if wid not in keep_ids)
    kept_with_media = sorted(wid for wid in all_seen if wid in keep_ids)

    overlap_error = keep_ids & set(purge_ids)
    if overlap_error:
        raise SystemExit(f"Internal error: purge list overlaps keep list: {sorted(overlap_error)[:5]}")

    planned_storage = sum(len(storage_by_word.get(w, [])) for w in purge_ids)
    planned_firestore = sum(len(firestore_by_word.get(w, [])) for w in purge_ids)

    print(f"Keep manifests: {[str(p.name) for p in manifest_paths]}")
    print(f"Keep word IDs: {len(keep_ids)}")
    print(f"Word IDs with Storage and/or Firestore video: {len(all_seen)}")
    print(f"Will keep media for: {len(kept_with_media)} word IDs")
    print(f"Will purge media for: {len(purge_ids)} word IDs")
    print(f"  Storage blobs: {planned_storage}")
    print(f"  Firestore video docs: {planned_firestore}")

    if purge_ids:
        sample = purge_ids[:25]
        print(f"  Sample purge word IDs: {', '.join(sample)}")
        if len(purge_ids) > 25:
            print(f"  ... and {len(purge_ids) - 25} more")

    if args.dry_run:
        print("\nDry run only — no changes written.")
        return

    all_storage_paths = [
        path for word_id in purge_ids for path in storage_by_word.get(word_id, [])
    ]

    print("\nDeleting Storage blobs...")
    storage_deleted = batch_delete_storage(bucket, all_storage_paths)

    print("Deleting Firestore video docs...")
    firestore_deleted = batch_delete_firestore_videos(db, firestore_by_word, purge_ids)

    print("Resetting parent word docs (videoCount=0)...")
    words_reset = batch_reset_word_parents(db, purge_ids)

    log = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "projectId": args.project_id,
        "bucket": args.bucket,
        "mode": "execute",
        "keepManifests": [str(p) for p in manifest_paths],
        "keepWordCount": len(keep_ids),
        "purgedWordCount": len(purge_ids),
        "storageBlobsDeleted": storage_deleted,
        "firestoreVideoDocsDeleted": firestore_deleted,
        "wordsParentReset": words_reset,
        "purgedWordIds": purge_ids,
        "keptWordIdsWithMedia": kept_with_media,
    }
    args.log.write_text(json.dumps(log, indent=2) + "\n", encoding="utf-8")

    print("\nPurge complete.")
    print(f"  Storage blobs deleted: {storage_deleted}")
    print(f"  Firestore video docs deleted: {firestore_deleted}")
    print(f"  words/{{id}} parent reset (videoCount=0): {words_reset}")
    print(f"  Audit log: {args.log.resolve()}")


if __name__ == "__main__":
    main()
