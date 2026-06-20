#!/usr/bin/env python3
"""Transcode filmed sign videos to H.264 MP4 for the app bundle."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_MAX_HEIGHT = 540
DEFAULT_VIDEO_BITRATE = "1400k"
DEFAULT_MAX_RATE = "2100k"
DEFAULT_BUF_SIZE = "4200k"
MAX_BYTES_PER_VIDEO = 1_500_000
DEFAULT_MAX_DURATION_SECONDS = 8.0


def load_bundle_word_ids(manifest_path: Path) -> list[str]:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    return data.get("bundleVideoWordIds", [])


def load_filmed_word_ids(repo_root: Path) -> list[str]:
    catalog = repo_root / "ASL" / "Shared" / "FilmedSignCatalog.swift"
    if not catalog.exists():
        raise FileNotFoundError(f"Missing filmed catalog: {catalog}")
    return sorted(set(re.findall(r'"([a-z0-9]+)"', catalog.read_text(encoding="utf-8"))))


def find_source_video(word_id: str, scripts_dir: Path) -> Path | None:
    for manifest_name in ("elijah_videos.json", "victoria_ariel_videos.json"):
        manifest_path = scripts_dir / manifest_name
        if not manifest_path.exists():
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        dataset_root = Path(manifest.get("datasetRoot", "")).expanduser()
        for video in manifest.get("videos", []):
            if video.get("wordId") != word_id:
                continue
            source = dataset_root / video.get("sourcePath", "")
            if source.exists():
                return source
    return None


def resolve_ffmpeg(explicit: str | None) -> str | None:
    if explicit:
        return explicit
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return None


def transcode(
    ffmpeg: str,
    source: Path,
    destination: Path,
    max_height: int,
    max_duration: float,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg,
        "-y",
        "-i",
        str(source),
        "-t",
        str(max_duration),
        "-vf",
        f"scale=-2:{max_height}",
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-b:v",
        DEFAULT_VIDEO_BITRATE,
        "-maxrate",
        DEFAULT_MAX_RATE,
        "-bufsize",
        DEFAULT_BUF_SIZE,
        "-an",
        "-movflags",
        "+faststart",
        str(destination),
    ]
    subprocess.run(command, check=True, capture_output=True)


def enforce_per_file_cap(output_dir: Path, word_ids: list[str], max_bytes: int) -> list[str]:
    kept: list[str] = []
    for word_id in word_ids:
        path = output_dir / f"{word_id}.mp4"
        if not path.exists():
            continue
        size = path.stat().st_size
        if size > max_bytes:
            path.unlink(missing_ok=True)
            print(
                f"dropped {word_id} ({size / 1024:.0f} KB) — exceeds per-file cap "
                f"({max_bytes / 1024:.0f} KB)",
                file=sys.stderr,
            )
            continue
        kept.append(word_id)
    return kept


def enforce_budget(output_dir: Path, word_ids: list[str], budget_bytes: int) -> list[str]:
    kept: list[str] = []
    total = 0
    for word_id in word_ids:
        path = output_dir / f"{word_id}.mp4"
        if not path.exists():
            continue
        size = path.stat().st_size
        if total + size > budget_bytes:
            path.unlink(missing_ok=True)
            print(f"dropped {word_id} ({size} bytes) — bundle video budget exceeded")
            continue
        total += size
        kept.append(word_id)
    print(f"bundle videos: {len(kept)} files, {total / 1_000_000:.1f} MB")
    return kept


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parent / "stone_media_manifest.json",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ASL" / "BundledMedia" / "Videos",
    )
    parser.add_argument(
        "--all-filmed",
        action="store_true",
        help="Transcode every word ID in FilmedSignCatalog.swift (default for full bundle).",
    )
    parser.add_argument("--budget-mb", type=int, default=170)
    parser.add_argument(
        "--max-bytes-per-video",
        type=int,
        default=MAX_BYTES_PER_VIDEO,
        help="Drop any output file larger than this (default 1.5 MB).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-transcode even when bundled MP4 already exists.",
    )
    parser.add_argument(
        "--max-duration",
        type=float,
        default=DEFAULT_MAX_DURATION_SECONDS,
        help="Trim source clips longer than this many seconds.",
    )
    parser.add_argument("--ffmpeg", default=None, help="Path to ffmpeg binary.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ffmpeg = resolve_ffmpeg(args.ffmpeg)
    if not ffmpeg and not args.dry_run:
        print("ffmpeg not found on PATH or via imageio-ffmpeg", file=sys.stderr)
        raise SystemExit(1)

    scripts_dir = Path(__file__).resolve().parent
    if args.all_filmed:
        word_ids = load_filmed_word_ids(args.repo_root)
    else:
        word_ids = load_bundle_word_ids(args.manifest)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Transcoding {len(word_ids)} word IDs…")

    for index, word_id in enumerate(word_ids, start=1):
        dest = args.output_dir / f"{word_id}.mp4"
        if not args.force and dest.exists() and dest.stat().st_size > 0:
            continue
        source = find_source_video(word_id, scripts_dir)
        if source is None:
            print(f"skip {word_id}: no local source in filmmaker manifests", file=sys.stderr)
            continue
        if args.dry_run:
            print(f"would transcode {word_id} from {source}")
            continue
        try:
            transcode(ffmpeg, source, dest, DEFAULT_MAX_HEIGHT, args.max_duration)
            if index % 50 == 0:
                print(f"Transcoded {index}/{len(word_ids)}…")
        except subprocess.CalledProcessError as exc:
            print(f"failed {word_id}: {exc.stderr.decode(errors='ignore')}", file=sys.stderr)

    if not args.dry_run:
        capped = enforce_per_file_cap(args.output_dir, word_ids, args.max_bytes_per_video)
        enforce_budget(args.output_dir, capped, args.budget_mb * 1024 * 1024)


if __name__ == "__main__":
    main()
