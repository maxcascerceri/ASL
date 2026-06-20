#!/usr/bin/env python3
"""Keep only filmmaker manifest videos on allowlisted word IDs.

Removes legacy pilot ``video_002``–``video_004`` Firestore docs and Storage blobs
so clients prefer the uploaded ``video_001.mov`` entries.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MANIFESTS = (
    SCRIPT_DIR / "elijah_videos.json",
    SCRIPT_DIR / "victoria_ariel_videos.json",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-manifest", type=Path, action="append", default=None)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--service-account", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    return parser.parse_args()


def init_firebase(project_id: str, bucket: str, service_account: Path | None):
    import firebase_admin
    from firebase_admin import credentials, firestore, storage

    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account) if service_account else credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {"projectId": project_id, "storageBucket": bucket})
    return firestore.client(), storage.bucket()


def load_manifest_paths(manifests: list[Path]) -> dict[str, str]:
    """wordId -> canonical storagePath from filmmaker upload."""
    keep: dict[str, str] = {}
    for path in manifests:
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data["videos"]:
            keep[entry["wordId"]] = entry["storagePath"]
    return keep


def main() -> None:
    args = parse_args()
    manifests = args.keep_manifest or list(DEFAULT_MANIFESTS)
    canonical = load_manifest_paths(manifests)

    db, bucket = init_firebase(args.project_id, args.bucket, args.service_account)

    extra_docs = 0
    extra_blobs = 0
    updated_parents = 0

    for word_id, keep_path in sorted(canonical.items()):
        word_ref = db.collection("words").document(word_id)
        videos = list(word_ref.collection("videos").stream())
        stale_docs = [v for v in videos if v.to_dict().get("storagePath") != keep_path]
        stale_paths = {v.to_dict().get("storagePath") for v in stale_docs}
        stale_paths.discard(None)

        prefix_blobs = [b.name for b in bucket.list_blobs(prefix=f"asl-videos/{word_id}/")]
        stale_blob_names = [p for p in prefix_blobs if p != keep_path]

        if stale_docs:
            extra_docs += len(stale_docs)
        if stale_blob_names:
            extra_blobs += len(stale_blob_names)

        if not stale_docs and not stale_blob_names:
            continue

        print(f"{word_id}: drop {len(stale_docs)} docs, {len(stale_blob_names)} blobs; keep {keep_path}")

        if args.dry_run:
            continue

        for doc in stale_docs:
            doc.reference.delete()
        if stale_blob_names:
            bucket.delete_blobs(stale_blob_names)

        keep_doc = next((v for v in videos if v.to_dict().get("storagePath") == keep_path), None)
        word_ref.set(
            {
                "videoCount": 1 if keep_doc or bucket.blob(keep_path).exists() else 0,
            },
            merge=True,
        )
        updated_parents += 1

    print(f"\nSummary: {len(canonical)} keep words")
    print(f"  Extra Firestore video docs: {extra_docs}")
    print(f"  Extra Storage blobs: {extra_blobs}")
    if args.execute:
        print(f"  Parent docs updated: {updated_parents}")


if __name__ == "__main__":
    main()
