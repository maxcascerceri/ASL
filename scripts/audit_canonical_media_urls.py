#!/usr/bin/env python3
"""Verify canonical dictionary media URLs return HTTP 200 for filmed pilot signs."""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BUCKET = "asl-app-718bf.firebasestorage.app"
VIDEO_NAME = "video_001.mov"
MOBILE_VIDEO_NAME = "video_001.mp4"
POSTER_NAME = "poster_001.jpg"
THUMB_120_NAME = "poster_thumb_120.jpg"
THUMB_360_NAME = "poster_thumb_360.jpg"


def canonical_url(storage_path: str) -> str:
    encoded = urllib.parse.quote(storage_path, safe="")
    return f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{encoded}?alt=media"


def load_filmed_word_ids(repo_root: Path) -> list[str]:
    catalog = repo_root / "ASL" / "Shared" / "FilmedSignCatalog.swift"
    text = catalog.read_text(encoding="utf-8")
    return sorted(set(re.findall(r'"([a-z0-9]+)"', text)))


def head_ok(url: str, timeout: float) -> tuple[bool, int]:
    request = urllib.request.Request(url, method="HEAD")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return 200 <= response.status < 300, response.status
    except urllib.error.HTTPError as error:
        return False, error.code
    except urllib.error.URLError:
        return False, 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--sample", type=int, default=0, help="Random sample size (0 = all).")
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument(
        "--include-thumbs",
        action="store_true",
        help="Also verify poster_thumb_120.jpg and poster_thumb_360.jpg.",
    )
    parser.add_argument(
        "--include-mobile-mp4",
        action="store_true",
        help="Also verify video_001.mp4 mobile variants.",
    )
    parser.add_argument("--json-out", type=Path, help="Write failures to JSON.")
    args = parser.parse_args()

    word_ids = load_filmed_word_ids(args.repo_root)
    if args.sample and args.sample < len(word_ids):
        word_ids = sorted(random.sample(word_ids, args.sample))

    failures: list[dict[str, str | int]] = []
    checked = 0

    for word_id in word_ids:
        assets = [
            ("video", f"asl-videos/{word_id}/{VIDEO_NAME}"),
            ("poster", f"asl-videos/{word_id}/{POSTER_NAME}"),
        ]
        if args.include_thumbs:
            assets.append(("thumb120", f"asl-videos/{word_id}/{THUMB_120_NAME}"))
            assets.append(("thumb360", f"asl-videos/{word_id}/{THUMB_360_NAME}"))
        if args.include_mobile_mp4:
            assets.append(("mobile_mp4", f"asl-videos/{word_id}/{MOBILE_VIDEO_NAME}"))

        for kind, path in assets:
            checked += 1
            url = canonical_url(path)
            ok, status = head_ok(url, args.timeout)
            if not ok:
                failures.append({"wordId": word_id, "kind": kind, "path": path, "status": status, "url": url})

    print(f"Checked {checked} blobs across {len(word_ids)} filmed signs.")
    print(f"Failures: {len(failures)}")
    for item in failures[:20]:
        print(f"  {item['wordId']} {item['kind']} status={item['status']}")

    if args.json_out:
        args.json_out.write_text(json.dumps(failures, indent=2), encoding="utf-8")

    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
