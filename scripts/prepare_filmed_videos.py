#!/usr/bin/env python3
"""Build an upload manifest from filmmaker video folders.

Maps human-readable filenames (e.g. ``"thank you".mov``, ``My name is.mov``) to
curriculum ``wordId``s and writes JSON for ``upload_firebase_pilot.py``.

When multiple takes exist for one sign, picks the file whose gloss best matches
the word's primary unit in ``curriculum-words-and-phrases.csv`` (e.g. directional
``left`` for Directions, not ``left`` depart).
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

from curriculum_v5_data import DISPLAY_OVERRIDES

SCRIPT_DIR = Path(__file__).resolve().parent
CATALOG_CSV = SCRIPT_DIR / "curriculum-words-and-phrases.csv"
ASSIGNMENTS_DIR = SCRIPT_DIR / "filming-assignments"
DEFAULT_COMBINED_CSVS = ("Ariel.csv", "Victoria.csv")

VIDEO_EXTENSIONS = {".mov", ".mp4", ".m4v", ".MP4", ".MOV"}

# Filenames containing any of these (lowercase) are not uploaded.
SKIP_FILENAME_CONTAINS = (
    "fall or fall down",
    "fall down",
)

# norm(filename gloss) -> word_id (bypasses display lookup)
DIRECT_WORD_IDS: dict[str, str] = {
    "thank you": "thankyou",
    "sign slow": "signslow",
    "sign language": "signlanguage",
    "how are you": "howareyou",
    "dont know": "dontknow",
    "don t know": "dontknow",
    "dont understand": "idontunderstand",
    "don t understand": "idontunderstand",
    "i dont understand": "idontunderstand",
    "i need help": "ineedhelp",
    "i wanr a drink": "iwantdrink",
    "i want a drink": "iwantdrink",
    "im excited": "imexcited",
    "im good": "imgood",
    "im happy": "imhappy",
    "im learning asl": "imlearningasl",
    "im scared": "imscared",
    "learn asl": "learnasl",
    "living room": "livingroom",
    "letter i": "letteri",
    "talk to you later": "talktoyoulater",
    "see you later": "seeyoulater",
    "good morning": "goodmorning",
    "what does that mean": "whatdoesthatmean",
    "what are you doing": "whatareyoudoing",
    "where is the bathroom": "wherebathroom",
    "wash dishes": "washdishes",
    "please help me": "pleasehelpme",
    "please sign slower": "pleasesignslower",
    "call 911": "call911",
    "1 dollar": "1dollar",
    "one hundred": "hundred",
    "computer mouse": "mouse",
    "blow mind": "blowmind",
    "let me see": "letmesee",
    "give up": "giveup",
    "let go": "letgo",
    "detach or disconnect": "letgo",
    "excuse me": "excuseme",
    "hard of hearing": "hardofhearing",
    "orange fruit": "orangefruit",
    "right correct": "rightcorrect",
    "america": "america",
    "usa": "america",
    "retirement": "retire",
    "grey": "gray",
    "quarter or 25cents": "quarter",
    "because": "because",
    "fall as in autumn": "fall",
    "love for objects locations activities": "love",
    "love for family or friends": "love",
    "car": "car",
    "car 1st variantion": "car",
    "car 2nd variation": "car",
    "911": "nineoneone",
}

def norm_key(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("\u201c", "").replace("\u201d", "").replace('"', "")
    text = text.replace("\u2018", "'").replace("\u2019", "'").replace("'", "'")
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


# Lower preference rank = chosen first when multiple files map to the same word_id.
# Substrings are matched against the full filename (lowercased).
VARIATION_FILE_HINTS: dict[str, list[tuple[str, int]]] = {
    "left": [("directional", 0), ("depart", 2), ("put down", 3)],
    "full": [("stuffed", 0), ("full of food", 0), ("complete or whole", 2)],
    "fall": [("autumn", 0)],
    "letter": [("alphabet", 0), ("mailing", 2), ("mail", 2)],
    "love": [("family", 0), ("friends", 0), ("objects", 2), ("activities", 2)],
    "light": [("ceiling", 0), ("light-weight", 2), ("weight", 2)],
    "ask": [("1st variation", 0), ("2nd variation", 2)],
    "car": [("1st", 0), ("2nd", 2)],
    "quarter": [("1st variation", 0), ("25cents", 1), ("25 cents", 1)],
    "1dollar": [("1st variation", 0), ("2nd variation", 2)],
    "letgo": [("detach", 0), ("disconnect", 0), ("let go", 1)],
    "america": [("america", 0), ("usa", 0)],
    "mouse": [("computer", 0)],
    "nineoneone": [("911", 0)],
    "call911": [("call 911", 0)],
}

# Dropbox filename stems -> norm_key of curriculum display title (legacy Elijah names)
FILENAME_ALIASES: dict[str, str] = {
    norm_key("My name is"): norm_key("My Name Is"),
    norm_key("Have a Good Day"): norm_key("Have A Good Day"),
    norm_key("How Do You Sign That"): norm_key("How Do You Sign That"),
    norm_key("Can You Repeat That"): norm_key("Can You Repeat That?"),
    norm_key("Right - Correct"): norm_key("Right / Correct"),
    norm_key("Where Are You From"): norm_key("Where Are You From?"),
    norm_key("How Many"): norm_key("How Many?"),
    norm_key("What's Your Name"): norm_key("What's Your Name"),
    norm_key("You're Welcome"): norm_key("You're Welcome"),
    norm_key("Nice To Meet You"): norm_key("Nice To Meet You"),
    norm_key("Name Sign"): norm_key("Name Sign"),
    norm_key("All Of A Sudden"): norm_key("All Of A Sudden"),
    norm_key("One More Time"): norm_key("One More Time"),
    norm_key("Orange Fruit"): norm_key("Orange Fruit"),
    norm_key("5 Dollars"): norm_key("5 Dollars"),
    norm_key("I Like"): norm_key("I Like"),
    norm_key("I'm Fine"): norm_key("I'm Fine"),
    norm_key("I'm Lost"): norm_key("I'm Lost"),
    norm_key("I'm Nervous"): norm_key("I'm Nervous"),
    norm_key("I'm Sad"): norm_key("I'm Sad"),
    norm_key("I'm Good"): norm_key("I'm Good"),
    norm_key("I'm Learning ASL"): norm_key("I'm Learning ASL"),
    norm_key("I Don't Understand"): norm_key("I Don't Understand"),
    norm_key("What Does That Mean"): norm_key("What Does That Mean"),
    norm_key("Please Help Me"): norm_key("Please Help Me"),
    norm_key("Let Me See"): norm_key("Let Me See"),
    norm_key("Give Up"): norm_key("Give Up"),
    norm_key("Let Go"): norm_key("Let Go"),
    norm_key("I Want To Drink"): norm_key("I Want To Drink"),
    norm_key("What Are You Doing"): norm_key("What Are You Doing?"),
    norm_key("Living Room"): norm_key("Living Room"),
    norm_key("Letter I"): norm_key("Letter I"),
    norm_key("America / USA"): norm_key("America / USA"),
    norm_key("Little"): norm_key("Little"),
    norm_key("Turn"): norm_key("Turn"),
    norm_key("Or"): norm_key("Or"),
}


def normalize_stem(stem: str) -> str:
    stem = stem.replace("\u201c", "").replace("\u201d", "").strip('"').strip()
    stem = stem.replace("\u2018", "'").replace("\u2019", "'")
    return stem.strip()


def should_skip_file(path: Path) -> bool:
    lower = path.name.lower()
    return any(token in lower for token in SKIP_FILENAME_CONTAINS)


def parse_lookup_stem(stem: str) -> str:
    """Reduce a filename stem to a catalog lookup key."""
    stem = normalize_stem(stem)
    if " depends on" in stem.lower():
        stem = stem.split(" depends on")[0]
    if " is being used for" in stem.lower():
        stem = stem.split(" is being used for")[0].strip()
    if " same as " in stem.lower():
        stem = stem.split(" same as ")[0].strip()
    if " not recommended" in stem.lower():
        stem = stem.split(" not recommended")[0].strip()

    stem = re.sub(r"\s*\(\d+(?:st|nd|rd|th)\s+variation\)", "", stem, flags=re.I)
    stem = re.sub(r"\s*\(\d+(?:st|nd|rd|th)\s+variantion\)", "", stem, flags=re.I)
    stem = re.sub(r"\s+variation\s+\d+", "", stem, flags=re.I)
    stem = re.sub(r"\s+variantion\s+\d+", "", stem, flags=re.I)

    if "(" in stem:
        main, rest = stem.split("(", 1)
        rest_l = rest.lower()
        descriptive = (
            "variation",
            "variantion",
            "depart",
            "directional",
            "put down",
            "complete",
            "stuffed",
            "ceiling",
            "light-weight",
            "autumn",
            "25cents",
            "cents",
            "also means",
            "for family",
            "for objects",
            "as in",
            "recommended",
            "mailing",
            "mail",
            "fall down",
        )
        if any(token in rest_l for token in descriptive) or len(main.strip()) <= 8:
            stem = main.strip()

    return stem.strip()


def variation_rank(path: Path) -> int:
    text = path.stem.lower()
    match = re.search(r"variation\s*(\d+)", text) or re.search(r"variantion\s*(\d+)", text)
    if match:
        return int(match.group(1))
    match = re.search(r"(\d+)(?:st|nd|rd|th)\s+variation", text)
    if match:
        return int(match.group(1))
    return 0


def preference_rank(word_id: str, path: Path) -> int:
    text = path.name.lower()
    hints = VARIATION_FILE_HINTS.get(word_id)
    if not hints:
        return 50
    best = 50
    for substring, rank in hints:
        if substring in text:
            best = min(best, rank)
    return best


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "folder",
        type=Path,
        help="Folder of filmed videos (e.g. ~/Desktop/victoriaarielsigns).",
    )
    parser.add_argument(
        "--assignment",
        type=Path,
        help="Optional filming-assignments/{Name}.csv to report missing/extra.",
    )
    parser.add_argument(
        "--combined",
        action="store_true",
        help="Expect union of Ariel + Victoria assignment lists (307 signs).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("filmed_videos.json"),
        help="Output manifest path (default: filmed_videos.json).",
    )
    parser.add_argument(
        "--filmmaker",
        type=str,
        default="",
        help="Label stored in manifest metadata (e.g. VictoriaAriel).",
    )
    return parser.parse_args()


def default_display(word_id: str) -> str:
    if word_id in DISPLAY_OVERRIDES:
        return DISPLAY_OVERRIDES[word_id]
    return re.sub(r"[_-]+", " ", word_id).title()


def build_display_lookup() -> dict[str, str]:
    lookup: dict[str, str] = {}
    if CATALOG_CSV.exists():
        with CATALOG_CSV.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                lookup[norm_key(row["display_name"])] = row["id"].strip()
    for word_id, display in DISPLAY_OVERRIDES.items():
        lookup[norm_key(display)] = word_id
    lookup[norm_key("America / USA")] = "america"
    return lookup


def build_unit_lookup() -> dict[str, str]:
    units: dict[str, str] = {}
    if not CATALOG_CSV.exists():
        return units
    with CATALOG_CSV.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            units[row["id"].strip()] = row.get("primary_unit_title", "").strip()
    return units


def resolve_word_id(stem: str, display_lookup: dict[str, str]) -> str | None:
    for candidate in (stem, parse_lookup_stem(stem)):
        key = norm_key(candidate)
        if key in DIRECT_WORD_IDS:
            return DIRECT_WORD_IDS[key]
        aliased = FILENAME_ALIASES.get(key, key)
        if aliased in display_lookup:
            return display_lookup[aliased]
        if aliased in DIRECT_WORD_IDS:
            return DIRECT_WORD_IDS[aliased]
        if key in display_lookup:
            return display_lookup[key]
        titled = norm_key(candidate.title())
        titled = FILENAME_ALIASES.get(titled, titled)
        if titled in display_lookup:
            return display_lookup[titled]
    return None


def assignment_title_to_word_id(title: str, display_lookup: dict[str, str]) -> str | None:
    key = norm_key(title)
    if key in display_lookup:
        return display_lookup[key]
    key = FILENAME_ALIASES.get(key, key)
    return display_lookup.get(key)


def load_assignment(path: Path | None) -> list[str]:
    if not path or not path.exists():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def load_combined_assignments() -> list[str]:
    titles: list[str] = []
    seen: set[str] = set()
    for name in DEFAULT_COMBINED_CSVS:
        path = ASSIGNMENTS_DIR / name
        for title in load_assignment(path):
            if title not in seen:
                seen.add(title)
                titles.append(title)
    return titles


def choose_best_file(word_id: str, paths: list[Path]) -> Path:
    return sorted(
        paths,
        key=lambda p: (preference_rank(word_id, p), variation_rank(p), p.name.lower()),
    )[0]


def selection_note(word_id: str, chosen: Path, all_paths: list[Path]) -> str | None:
    if len(all_paths) < 2:
        return None
    rank = preference_rank(word_id, chosen)
    unit = build_unit_lookup().get(word_id, "")
    if rank < 50:
        return f"unit={unit!r}, matched filename hint (rank {rank})"
    if variation_rank(chosen) > 0:
        return f"unit={unit!r}, lowest variation number"
    return f"unit={unit!r}, first filename"


def main() -> None:
    args = parse_args()
    folder = args.folder.expanduser().resolve()
    if not folder.is_dir():
        raise SystemExit(f"Not a directory: {folder}")

    display_lookup = build_display_lookup()
    unit_lookup = build_unit_lookup()

    if args.combined:
        assignment = load_combined_assignments()
        filmmaker = args.filmmaker or "VictoriaAriel"
        assignment_label = "Ariel.csv+Victoria.csv"
    else:
        assignment = load_assignment(args.assignment)
        filmmaker = args.filmmaker or None
        assignment_label = str(args.assignment.resolve()) if args.assignment else None

    video_files = sorted(
        p for p in folder.iterdir() if p.is_file() and p.suffix in VIDEO_EXTENSIONS
    )
    if not video_files:
        raise SystemExit(f"No video files found in {folder}")

    by_word: dict[str, list[Path]] = {}
    unmapped: list[str] = []
    skipped: list[str] = []

    for path in video_files:
        if should_skip_file(path):
            skipped.append(path.name)
            continue
        word_id = resolve_word_id(path.stem, display_lookup)
        if not word_id:
            unmapped.append(path.name)
            continue
        by_word.setdefault(word_id, []).append(path)

    selected: list[dict] = []
    selection_log: list[dict] = []

    for word_id in sorted(by_word.keys()):
        paths = by_word[word_id]
        chosen = choose_best_file(word_id, paths)
        entry = {
            "wordId": word_id,
            "text": default_display(word_id),
            "primaryUnitTitle": unit_lookup.get(word_id),
            "videoId": "video_001",
            "sourcePath": chosen.name,
            "storagePath": f"asl-videos/{word_id}/video_001{chosen.suffix.lower()}",
            "sortOrder": 1,
            "fileSizeBytes": chosen.stat().st_size,
            "sourceFilename": chosen.name,
        }
        note = selection_note(word_id, chosen, paths)
        if note:
            entry["selectionNote"] = note
        selected.append(entry)

        if len(paths) > 1:
            selection_log.append(
                {
                    "wordId": word_id,
                    "display": default_display(word_id),
                    "picked": chosen.name,
                    "alternates": [p.name for p in paths if p != chosen],
                    "note": note,
                }
            )

    expected_ids: list[str] = []
    pending: list[dict] = []
    if assignment:
        for title in assignment:
            wid = assignment_title_to_word_id(title, display_lookup)
            if wid:
                expected_ids.append(wid)
                if wid not in by_word:
                    pending.append(
                        {
                            "display": title,
                            "wordId": wid,
                            "primaryUnitTitle": unit_lookup.get(wid),
                        }
                    )

    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "datasetRoot": str(folder),
        "filmmaker": filmmaker,
        "assignmentCsv": assignment_label,
        "combined": bool(args.combined),
        "videoCount": len(selected),
        "expectedSignCount": len(expected_ids) if expected_ids else None,
        "readySignCount": len(set(expected_ids) & set(by_word.keys())) if expected_ids else None,
        "pendingSignCount": len(pending) if expected_ids else None,
        "pending": pending,
        "skippedFiles": skipped,
        "selectionLog": selection_log,
        "videos": selected,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"Folder: {folder}")
    print(f"Video files scanned: {len(video_files)}")
    print(f"Skipped (non-curriculum): {len(skipped)}")
    print(f"Mapped to word IDs: {len(selected)}")
    print(f"Wrote {args.output.resolve()}")

    if unmapped:
        print(f"\nUnmapped files ({len(unmapped)}):")
        for name in unmapped:
            print(f"  ? {name}")

    if expected_ids:
        got_ids = {v["wordId"] for v in selected}
        missing_display = [p["display"] for p in pending]
        print(f"\nAssignment check ({assignment_label}):")
        print(f"  Expected: {len(expected_ids)}")
        print(f"  Ready now: {len(expected_ids) - len(pending)}")
        print(f"  Pending (film later): {len(pending)}")
        if pending:
            print("  Pending list:")
            for item in pending:
                print(f"    - {item['display']} ({item['wordId']})")

        extra_ids = got_ids - set(expected_ids)
        if extra_ids:
            print(f"  Extra word IDs not on assignment ({len(extra_ids)}):")
            for w in sorted(extra_ids)[:15]:
                print(f"    + {default_display(w)} ({w})")
            if len(extra_ids) > 15:
                print(f"    ... and {len(extra_ids) - 15} more")

    if selection_log:
        print(f"\nDuplicate takes resolved ({len(selection_log)} signs):")
        for item in selection_log[:15]:
            print(f"  {item['display']}: {item['picked']}")
            if item["alternates"]:
                print(f"    (not used: {', '.join(item['alternates'][:2])}"
                      f"{'...' if len(item['alternates']) > 2 else ''})")
        if len(selection_log) > 15:
            print(f"  ... and {len(selection_log) - 15} more")


if __name__ == "__main__":
    main()
