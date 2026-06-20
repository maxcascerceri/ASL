#!/usr/bin/env python3
"""Download poster_thumb_360.jpg for all filmed signs into ASL/BundledMedia/Posters/."""

from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BUCKET = "asl-app-718bf.firebasestorage.app"
THUMB_NAME = "poster_thumb_360.jpg"


def canonical_url(storage_path: str) -> str:
    encoded = urllib.parse.quote(storage_path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{encoded}?alt=media"


def filmed_word_ids(repo_root: Path) -> list[str]:
    catalog = repo_root / "ASL" / "Shared" / "FilmedSignCatalog.swift"
    return sorted(set(re.findall(r'"([a-z0-9]+)"', catalog.read_text(encoding="utf-8"))))


def download(url: str, destination: Path, timeout: float) -> None:
    request = urllib.request.Request(url)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        destination.write_bytes(response.read())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ASL" / "BundledMedia" / "Posters",
    )
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    word_ids = filmed_word_ids(args.repo_root)
    failed = 0

    for index, word_id in enumerate(word_ids, start=1):
        dest = args.output_dir / f"{word_id}.jpg"
        if dest.exists() and dest.stat().st_size > 0:
            continue
        storage_path = f"asl-videos/{word_id}/{THUMB_NAME}"
        url = canonical_url(storage_path)
        if args.dry_run:
            print(f"would download {word_id}")
            continue
        try:
            download(url, dest, args.timeout)
        except (urllib.error.URLError, urllib.error.HTTPError) as exc:
            print(f"failed {word_id}: {exc}", file=sys.stderr)
            failed += 1
        if index % 50 == 0:
            print(f"downloaded {index}/{len(word_ids)}…")

    print(f"Done: {len(word_ids)} targets, {failed} failures, output={args.output_dir}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
