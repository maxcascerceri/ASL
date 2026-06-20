#!/usr/bin/env python3
"""Validate ASL tip catalog editorial and pairing rules."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

from asl_tips_catalog import ASL_TIPS_CATALOG, DUPLICATE_WORDID_ALLOWLIST

MAX_CHARS = 120
WARN_CHARS = 110

BANNED_JARGON = [
    r"\bwh-questions?\b",
    r"\bnegate\b",
    r"\bfacial grammar\b",
    r"\bDeaf space\b",
    r"\bsimcom\b",
    r"\breferents?\b",
    r"\bbackchannel",
    r"\bmouth morphemes?\b",
    r"\btopic-comment\b",
    r"\binitialized signs?\b",
]

APP_REFERENCE = [
    r"\breplay\b",
    r"\bthis app\b",
    r"\bthe lesson\b",
    r"\bin this lesson\b",
]


def load_known_word_ids(scripts_dir: Path) -> set[str]:
    curriculum_path = scripts_dir / "curriculum.json"
    words: set[str] = set()
    if curriculum_path.exists():
        data = json.loads(curriculum_path.read_text(encoding="utf-8"))
        for path in data.get("paths", []):
            for unit in path.get("units", []):
                words.update(unit.get("words", []))
                for lesson in unit.get("lessons", []):
                    words.update(lesson.get("wordIds", []))

    poster_dir = scripts_dir.parent / "ASL" / "BundledMedia" / "Posters"
    if poster_dir.is_dir():
        words.update(p.stem for p in poster_dir.glob("*.jpg"))

    return words


def validate() -> list[str]:
    errors: list[str] = []
    warnings: list[str] = []

    ids = [tip["id"] for tip in ASL_TIPS_CATALOG]
    if len(ids) != len(set(ids)):
        errors.append("Duplicate tip IDs in catalog")

    known_words = load_known_word_ids(Path(__file__).resolve().parent)
    word_id_counts: Counter[str] = Counter()

    em_dash_count = 0
    dont_start_count = 0

    for tip in ASL_TIPS_CATALOG:
        tip_id = tip["id"]
        text = tip.get("text", "")
        word_id = tip.get("wordId", "")

        if not text.strip():
            errors.append(f"{tip_id}: empty text")
            continue

        if len(text) > MAX_CHARS:
            errors.append(f"{tip_id}: text length {len(text)} exceeds {MAX_CHARS}")
        elif len(text) > WARN_CHARS:
            warnings.append(f"{tip_id}: text length {len(text)} exceeds {WARN_CHARS}")

        if text.strip().lower().startswith("don't"):
            dont_start_count += 1

        if " — " in text:
            em_dash_count += 1

        for pattern in BANNED_JARGON:
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(f"{tip_id}: banned jargon matches {pattern!r}")

        for pattern in APP_REFERENCE:
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(f"{tip_id}: app reference matches {pattern!r}")

        if re.search(r"\b[A-Z]{2,}\b", text) and not re.search(
            r"\bASL\b", text
        ):
            caps = re.findall(r"\b[A-Z]{2,}\b", text)
            if caps:
                warnings.append(f"{tip_id}: ALL CAPS tokens {caps}")

        if word_id:
            word_id_counts[word_id] += 1
            if word_id not in known_words:
                errors.append(f"{tip_id}: unknown wordId {word_id!r}")
        else:
            errors.append(f"{tip_id}: missing wordId (always-video policy)")

    for word_id, count in word_id_counts.items():
        if count > 1 and word_id not in DUPLICATE_WORDID_ALLOWLIST:
            errors.append(
                f"wordId {word_id!r} used {count} times (not in DUPLICATE_WORDID_ALLOWLIST)"
            )

    if ASL_TIPS_CATALOG and em_dash_count > len(ASL_TIPS_CATALOG) / 2:
        warnings.append(
            f"Em-dash overuse: {em_dash_count}/{len(ASL_TIPS_CATALOG)} tips use ' — '"
        )

    dont_pct = (dont_start_count / len(ASL_TIPS_CATALOG)) * 100 if ASL_TIPS_CATALOG else 0
    if dont_pct > 15:
        warnings.append(
            f"{dont_start_count} tips ({dont_pct:.0f}%) start with Don't (target <=15%)"
        )

    if warnings:
        print(f"Warnings ({len(warnings)}):")
        for warning in warnings:
            print(f"  - {warning}")

    return errors


def main() -> None:
    errors = validate()
    tip_count = len(ASL_TIPS_CATALOG)
    print(f"Validated {tip_count} tips")

    if errors:
        print(f"Errors ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        sys.exit(1)

    print("OK — all tip checks passed")


if __name__ == "__main__":
    main()
