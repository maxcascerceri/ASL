#!/usr/bin/env python3
"""Upload selected ASL pilot videos to Firebase Storage and Firestore."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import uuid
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore, storage


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "manifest",
        type=Path,
        help="Manifest from prepare_asl_pilot.py or prepare_filmed_videos.py.",
    )
    parser.add_argument("--dataset-root", type=Path, help="Override dataset root from the manifest.")
    parser.add_argument("--project-id", required=True, help="Firebase project ID, for example asl-app-718bf.")
    parser.add_argument("--bucket", required=True, help="Firebase Storage bucket, for example asl-app-718bf.firebasestorage.app.")
    parser.add_argument("--service-account", type=Path, help="Optional Firebase service account JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned uploads without writing to Firebase.")
    return parser.parse_args()


def poster_storage_path(video_storage_path: str) -> str:
    parts = video_storage_path.split("/")
    parts[-1] = "poster_001.jpg"
    return "/".join(parts)


def poster_thumb_storage_path(video_storage_path: str, size: int = 360) -> str:
    parts = video_storage_path.split("/")
    parts[-1] = f"poster_thumb_{size}.jpg"
    return "/".join(parts)


def extract_poster_jpeg(source_video: Path, destination_jpeg: Path) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            "0.15",
            "-i",
            str(source_video),
            "-frames:v",
            "1",
            "-q:v",
            "2",
            str(destination_jpeg),
        ],
        check=True,
        capture_output=True,
    )


def extract_poster_thumb(source_jpeg: Path, destination_jpeg: Path, size: int = 120) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(source_jpeg),
            "-vf",
            f"scale={size}:{size}:force_original_aspect_ratio=decrease",
            "-q:v",
            "4",
            str(destination_jpeg),
        ],
        check=True,
        capture_output=True,
    )


def initialize_firebase(project_id: str, bucket: str, service_account: Path | None) -> None:
    if firebase_admin._apps:
        return

    if service_account:
        credential = credentials.Certificate(service_account)
    else:
        credential = credentials.ApplicationDefault()

    firebase_admin.initialize_app(
        credential,
        {
            "projectId": project_id,
            "storageBucket": bucket,
        },
    )


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    dataset_root = (args.dataset_root or Path(manifest["datasetRoot"])).expanduser().resolve()

    if args.dry_run:
        print(f"Dry run: {len(manifest['videos'])} videos from {dataset_root}")
        for video in manifest["videos"][:10]:
            print(f"{video['sourcePath']} -> gs://{args.bucket}/{video['storagePath']}")
        return

    initialize_firebase(args.project_id, args.bucket, args.service_account)
    db = firestore.client()
    bucket = storage.bucket()

    words: dict[str, dict] = {}

    for video in manifest["videos"]:
        source_file = dataset_root / video["sourcePath"]
        if not source_file.exists():
            raise FileNotFoundError(f"Missing source video: {source_file}")

        blob = bucket.blob(video["storagePath"])
        blob.cache_control = "public, max-age=86400"
        blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
        suffix = source_file.suffix.lower()
        content_type = "video/quicktime" if suffix == ".mov" else "video/mp4"
        blob.upload_from_filename(str(source_file), content_type=content_type)

        poster_path = poster_storage_path(video["storagePath"])
        with tempfile.TemporaryDirectory() as tmp:
            poster_file = Path(tmp) / "poster_001.jpg"
            grid_thumb_file = Path(tmp) / "poster_thumb_360.jpg"
            extract_poster_jpeg(source_file, poster_file)
            extract_poster_thumb(poster_file, grid_thumb_file, size=360)

            poster_blob = bucket.blob(poster_path)
            poster_blob.cache_control = "public, max-age=86400"
            poster_blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
            poster_blob.upload_from_filename(str(poster_file), content_type="image/jpeg")

            grid_thumb_path = poster_thumb_storage_path(video["storagePath"], size=360)
            grid_thumb_blob = bucket.blob(grid_thumb_path)
            grid_thumb_blob.cache_control = "public, max-age=86400"
            grid_thumb_blob.metadata = {"firebaseStorageDownloadTokens": str(uuid.uuid4())}
            grid_thumb_blob.upload_from_filename(str(grid_thumb_file), content_type="image/jpeg")

        word_id = video["wordId"]
        words.setdefault(
            word_id,
            {
                "text": video["text"],
                "normalizedText": word_id,
                "videoCount": 0,
                "categoryIds": ["pilot"],
                "published": True,
            },
        )
        words[word_id]["videoCount"] += 1
        words[word_id]["posterStoragePath"] = poster_path

        db.collection("words").document(word_id).collection("videos").document(video["videoId"]).set(
            {
                "word": video["text"],
                "storagePath": video["storagePath"],
                "sourcePath": video["sourcePath"],
                "sortOrder": video["sortOrder"],
                "fileSizeBytes": video["fileSizeBytes"],
                "published": True,
            }
        )

    for word_id, word in words.items():
        db.collection("words").document(word_id).set(word, merge=True)

    print(f"Uploaded {len(manifest['videos'])} videos and {len(words)} word documents.")


if __name__ == "__main__":
    main()
