#!/usr/bin/env python3
"""Validate the ASL dataset and select a small Firebase pilot manifest.

Handles two real-world layouts of the American Sign Language Dataset:

1. README layout (word, video_path) where the path already includes the part
   folder, for example "part1/12345-HELLO.mp4".
2. AslenseDataset layout (word, videos) where only the filename is provided
   and videos are spread across part_1..part_11 folders.

The script auto-detects the CSV file, column names, and part folder naming.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

WORD_COLUMN_CANDIDATES = ("word", "label", "text")
PATH_COLUMN_CANDIDATES = ("video_path", "videos", "video", "filename", "path")


def word_id_for(word: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", word.strip().lower())
    return normalized.strip("-") or "unknown"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset_root", type=Path, help="Folder containing the dataset CSV and part folders.")
    parser.add_argument("--csv", type=Path, help="Optional CSV path; defaults to first matching file in dataset_root.")
    parser.add_argument("--output", type=Path, default=Path("selected_videos.json"))
    parser.add_argument("--max-words", type=int, default=50)
    parser.add_argument("--videos-per-word", type=int, default=4)
    parser.add_argument(
        "--selection",
        choices=("smallest", "first"),
        default="smallest",
        help="Use smallest files for faster pilot uploads, or preserve CSV order.",
    )
    return parser.parse_args()


def find_csv(dataset_root: Path, override: Path | None) -> Path:
    if override:
        path = override if override.is_absolute() else dataset_root / override
        if not path.exists():
            raise FileNotFoundError(f"CSV not found at {path}")
        return path

    matches = sorted(p for p in dataset_root.glob("*.csv") if not p.name.startswith("."))
    if not matches:
        raise FileNotFoundError(f"No CSV file found in {dataset_root}")
    return matches[0]


def detect_column(fieldnames: list[str], candidates: tuple[str, ...]) -> str:
    lookup = {name.lower(): name for name in fieldnames}
    for candidate in candidates:
        if candidate in lookup:
            return lookup[candidate]
    raise ValueError(
        f"Could not find any of the expected columns {candidates} in CSV header {fieldnames}"
    )


def index_part_folders(dataset_root: Path) -> dict[str, str]:
    """Return {filename: relative_path} for every video under part folders.

    Supports both `partN` and `part_N` naming. The first match wins, which
    matches CSVs that reference filenames without specifying which part they
    live in.
    """
    pattern = re.compile(r"^part[_-]?(\d+)$", re.IGNORECASE)
    index: dict[str, str] = {}
    for entry in sorted(dataset_root.iterdir()):
        if not entry.is_dir() or not pattern.match(entry.name):
            continue
        for video in entry.iterdir():
            if not video.is_file():
                continue
            relative = f"{entry.name}/{video.name}"
            index.setdefault(video.name, relative)
            index.setdefault(relative, relative)
    return index


def load_rows(dataset_root: Path, csv_path: Path) -> tuple[list[dict], list[dict], dict[str, str]]:
    file_index = index_part_folders(dataset_root)
    valid_rows: list[dict] = []
    missing_rows: list[dict] = []

    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"{csv_path.name} has no header row")

        word_column = detect_column(reader.fieldnames, WORD_COLUMN_CANDIDATES)
        path_column = detect_column(reader.fieldnames, PATH_COLUMN_CANDIDATES)

        for row_number, row in enumerate(reader, start=2):
            word = (row.get(word_column) or "").strip()
            raw_path = (row.get(path_column) or "").strip()
            if not word or not raw_path:
                missing_rows.append(
                    {"row": row_number, "word": word, "videos": raw_path, "reason": "blank field"}
                )
                continue

            relative_path = resolve_relative_path(raw_path, dataset_root, file_index)
            if relative_path is None:
                missing_rows.append(
                    {"row": row_number, "word": word, "videos": raw_path, "reason": "missing file"}
                )
                continue

            absolute_path = dataset_root / relative_path
            valid_rows.append(
                {
                    "row": row_number,
                    "word": word,
                    "wordId": word_id_for(word),
                    "sourcePath": relative_path,
                    "absolutePath": str(absolute_path),
                    "fileSizeBytes": absolute_path.stat().st_size,
                }
            )

    return valid_rows, missing_rows, file_index


def resolve_relative_path(raw_path: str, dataset_root: Path, file_index: dict[str, str]) -> str | None:
    candidate = (dataset_root / raw_path).resolve()
    if candidate.exists() and candidate.is_file():
        try:
            return str(candidate.relative_to(dataset_root.resolve())).replace("\\", "/")
        except ValueError:
            return raw_path

    indexed = file_index.get(raw_path)
    if indexed:
        return indexed

    filename = raw_path.replace("\\", "/").split("/")[-1]
    return file_index.get(filename)


def select_videos(rows: list[dict], max_words: int, videos_per_word: int, selection: str) -> list[dict]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    display_words: dict[str, str] = {}

    for row in rows:
        grouped[row["wordId"]].append(row)
        display_words.setdefault(row["wordId"], row["word"])

    selected: list[dict] = []
    for word_id in sorted(grouped.keys())[:max_words]:
        candidates = grouped[word_id]
        if selection == "smallest":
            candidates = sorted(candidates, key=lambda item: (item["fileSizeBytes"], item["sourcePath"]))

        for index, row in enumerate(candidates[:videos_per_word], start=1):
            video_id = f"video_{index:03d}"
            selected.append(
                {
                    "wordId": word_id,
                    "text": display_words[word_id],
                    "videoId": video_id,
                    "sourcePath": row["sourcePath"],
                    "storagePath": f"asl-videos/{word_id}/{video_id}.mp4",
                    "sortOrder": index,
                    "fileSizeBytes": row["fileSizeBytes"],
                }
            )

    return selected


def main() -> None:
    args = parse_args()
    dataset_root = args.dataset_root.expanduser().resolve()
    csv_path = find_csv(dataset_root, args.csv)
    print(f"Using dataset root: {dataset_root}")
    print(f"Using CSV: {csv_path.name}")

    rows, missing_rows, file_index = load_rows(dataset_root, csv_path)
    print(f"Indexed {len(file_index)} files across part folders.")

    selected = select_videos(rows, args.max_words, args.videos_per_word, args.selection)

    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "datasetRoot": str(dataset_root),
        "csvPath": str(csv_path),
        "stats": {
            "validVideos": len(rows),
            "missingOrInvalidRows": len(missing_rows),
            "uniqueWords": len({row["wordId"] for row in rows}),
            "selectedVideos": len(selected),
            "selectedWords": len({row["wordId"] for row in selected}),
            "selectedBytes": sum(row["fileSizeBytes"] for row in selected),
        },
        "missingRowsSample": missing_rows[:25],
        "videos": selected,
    }

    args.output.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest["stats"], indent=2))
    print(f"Wrote manifest to {args.output}")


if __name__ == "__main__":
    main()
