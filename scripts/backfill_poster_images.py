#!/usr/bin/env python3
"""Extract and upload poster_001.jpg for filmmaker videos in Firebase Storage."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
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
        help="Only process video blobs under this prefix.",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Max posters to process (0 = all).")
    return parser.parse_args()


def resolve_ffmpeg() -> str:
    override = os.environ.get("FFMPEG")
    if override and Path(override).is_file():
        return override
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg

        bundled = imageio_ffmpeg.get_ffmpeg_exe()
        if Path(bundled).is_file():
            return bundled
    except ImportError:
        pass
    raise RuntimeError(
        "ffmpeg not found. Install ffmpeg, pip install imageio-ffmpeg, or set FFMPEG=/path/to/ffmpeg"
    )


def poster_path_for(video_storage_path: str) -> str:
    # asl-videos/thankyou/video_001.mov -> asl-videos/thankyou/poster_001.jpg
    parts = video_storage_path.split("/")
    if len(parts) < 3:
        raise ValueError(f"Unexpected storage path: {video_storage_path}")
    parts[-1] = "poster_001.jpg"
    return "/".join(parts)


def extract_poster(ffmpeg: str, video_bytes_path: Path, poster_path: Path) -> None:
    subprocess.run(
        [
            ffmpeg,
            "-y",
            "-ss",
            "0.15",
            "-i",
            str(video_bytes_path),
            "-frames:v",
            "1",
            "-q:v",
            "2",
            str(poster_path),
        ],
        check=True,
        capture_output=True,
    )


def main() -> None:
    args = parse_args()
    ffmpeg: str | None = None
    if not args.dry_run:
        try:
            ffmpeg = resolve_ffmpeg()
            print(f"Using ffmpeg: {ffmpeg}")
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            raise SystemExit(1) from exc

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
    failed = 0
    processed = 0

    for blob in bucket.list_blobs(prefix=args.prefix):
        name = blob.name
        if not name.endswith((".mov", ".mp4", ".m4v")):
            continue
        if "/video_" not in name:
            continue

        processed += 1
        if args.limit and uploaded + skipped + failed >= args.limit:
            break

        poster_storage = poster_path_for(name)
        poster_blob = bucket.blob(poster_storage)
        if poster_blob.exists():
            skipped += 1
            continue

        if args.dry_run:
            print(f"would upload poster for {name}")
            uploaded += 1
            continue

        try:
            with tempfile.TemporaryDirectory() as tmp:
                tmp_dir = Path(tmp)
                video_file = tmp_dir / "video" / Path(name).name
                video_file.parent.mkdir(parents=True, exist_ok=True)
                poster_file = tmp_dir / "poster.jpg"
                blob.download_to_filename(str(video_file))
                extract_poster(ffmpeg, video_file, poster_file)
                poster_blob.cache_control = "public, max-age=86400"
                poster_blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
                poster_blob.upload_from_filename(str(poster_file), content_type="image/jpeg")
            uploaded += 1
            if uploaded % 25 == 0:
                print(f"Uploaded {uploaded} posters…")
        except (subprocess.CalledProcessError, OSError) as exc:
            print(f"Failed {name}: {exc}", file=sys.stderr)
            failed += 1

    print(
        json.dumps(
            {
                "bucket": args.bucket,
                "videosScanned": processed,
                "uploaded": uploaded,
                "skippedExisting": skipped,
                "failed": failed,
                "dryRun": args.dry_run,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
