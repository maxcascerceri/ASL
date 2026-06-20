#!/usr/bin/env python3
"""Generate and upload grid poster thumbs from existing poster_001.jpg blobs."""

from __future__ import annotations

import argparse
import io
import sys
import uuid
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, storage

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install Pillow", file=sys.stderr)
    raise SystemExit(1)

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
    parser.add_argument("--thumb-size", type=int, default=360, help="Max side in pixels (default 360).")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-upload even if thumb blob already exists.",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def thumb_path(poster_path: str, size: int) -> str:
    return poster_path.replace("poster_001.jpg", f"poster_thumb_{size}.jpg")


def make_thumb_jpeg(data: bytes, size: int) -> bytes:
    image = Image.open(io.BytesIO(data))
    image = image.convert("RGB")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    out = io.BytesIO()
    image.save(out, format="JPEG", quality=82, optimize=True)
    return out.getvalue()


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
    uploaded = 0
    skipped = 0

    for blob in bucket.list_blobs(prefix=args.prefix):
        if not blob.name.endswith("/poster_001.jpg"):
            continue

        destination = thumb_path(blob.name, args.thumb_size)
        if not args.force and bucket.blob(destination).exists():
            skipped += 1
            continue

        if args.dry_run:
            print(f"would upload {destination}")
            uploaded += 1
            continue

        blob.reload()
        thumb_bytes = make_thumb_jpeg(blob.download_as_bytes(), args.thumb_size)
        thumb_blob = bucket.blob(destination)
        thumb_blob.cache_control = "public, max-age=86400"
        thumb_blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
        thumb_blob.upload_from_string(thumb_bytes, content_type="image/jpeg")
        uploaded += 1
        if uploaded % 50 == 0:
            print(f"  uploaded {uploaded} thumbs...", flush=True)

    print(f"Uploaded: {uploaded}, skipped existing: {skipped}")


if __name__ == "__main__":
    main()
