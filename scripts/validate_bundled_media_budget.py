#!/usr/bin/env python3
"""Fail if BundledMedia exceeds the IPA media budget."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Hero/onboarding clips are full-screen 1080p and intentionally larger than sign videos.
PER_FILE_CAP_EXEMPT_STEMS = frozenset({"onboarding-welcome"})


def folder_size(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument("--max-mb", type=int, default=170)
    parser.add_argument(
        "--max-bytes-per-video",
        type=int,
        default=1_500_000,
        help="Report any single MP4 larger than this (default 1.5 MB).",
    )
    args = parser.parse_args()

    bundled_root = args.repo_root / "ASL" / "BundledMedia"
    posters_dir = bundled_root / "Posters"
    videos_dir = bundled_root / "Videos"
    max_bytes = args.max_mb * 1024 * 1024

    posters_bytes = folder_size(posters_dir)
    videos_bytes = folder_size(videos_dir)
    total_bytes = posters_bytes + videos_bytes

    poster_count = len(list(posters_dir.glob("*.jpg"))) if posters_dir.exists() else 0
    video_files = sorted(videos_dir.glob("*.mp4")) if videos_dir.exists() else []
    outliers = [
        path
        for path in video_files
        if path.stem not in PER_FILE_CAP_EXEMPT_STEMS
        and path.stat().st_size > args.max_bytes_per_video
    ]

    print(f"BundledMedia posters: {poster_count} files, {posters_bytes / 1_000_000:.2f} MB")
    print(f"BundledMedia videos:  {len(video_files)} files, {videos_bytes / 1_000_000:.2f} MB")
    print(f"BundledMedia total:   {total_bytes / 1_000_000:.2f} MB (cap {args.max_mb} MB)")

    errors: list[str] = []
    if total_bytes > max_bytes:
        errors.append(
            f"BundledMedia total {total_bytes / 1_000_000:.2f} MB exceeds cap {args.max_mb} MB"
        )
    if outliers:
        sample = ", ".join(
            f"{path.stem} ({path.stat().st_size / 1024:.0f} KB)" for path in outliers[:5]
        )
        errors.append(
            f"{len(outliers)} video(s) exceed per-file cap "
            f"({args.max_bytes_per_video / 1024:.0f} KB): {sample}"
        )

    if errors:
        for message in errors:
            print(f"ERROR: {message}", file=sys.stderr)
        raise SystemExit(1)

    print("Bundled media budget OK.")


if __name__ == "__main__":
    main()
