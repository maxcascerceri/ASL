#!/usr/bin/env python3
"""Export Signs-tab categories, words, and mascot asset names."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIGNS_SWIFT = ROOT / "ASL" / "Tabs" / "SignsTabView.swift"
MODELS_SWIFT = ROOT / "ASL" / "ASLModels.swift"
OUT_CSV = Path(__file__).resolve().parent / "signs-categories-and-words.csv"
OUT_MD = Path(__file__).resolve().parent / "signs-categories-and-words.md"

# Signs category title → mascot asset name (from ASLUnitMascot.byTitle + closest unit theme).
CATEGORY_MASCOT: dict[str, str] = {
    "First Signs": "greetings",
    "Quick Responses": "smalltalk",
    "Everyday Replies": "smalltalk",
    "Pronouns & Possessives": "mine and yours",
    "Question Words": "questions",
    "People Words": "people",
    "Check-ins": "mood",
    "Deaf World Basics": "languages",
    "Alphabet": "abcs1",
    "Fingerspelling": "spelling",
    "Numbers": "numbers",
    "Money": "money",
    "Amounts & Math": "howmuch",
    "Sentence Helpers": "andbut",
    "Family": "family",
    "People": "people",
    "Movement": "gettingaround",
    "Body Actions": "doingthings",
    "Communication": "talking",
    "Doing & Helping": "doingthings",
    "Colors": "colors",
    "Descriptions": "describingthings",
    "Home": "home",
    "Furniture": "furniture",
    "Hygiene": "routine",
    "Chores": "chores",
    "Mealtime": "mealtime",
    "Fruit": "fruits",
    "Vegetables": "vegetables",
    "Protein & Dairy": "meatdairy",
    "Snacks & Drinks": "snacks",
    "Weekdays": "daysofweek",
    "Time of Day": "when",
    "Time Units": "time",
    "Head & Face": "headface",
    "Body": "body",
    "Symptoms": "feelingsick",
    "Health": "health",
    "Personality": "personality",
    "Big Feelings": "bigfeelings",
    "Relationships": "love",
    "Clothing": "outfits",
    "Accessories": "accessories",
    "Transportation": "gettingaround",
    "Directions": "directions",
    "Places": "aroundtown",
    "Commute": "commute",
    "School": "school",
    "Work": "work",
    "Pets & Farm": "pets",
    "Wild Animals": "wildanimals",
    "Nature & Seasons": "nature",
    "Weather": "weather",
    "Sports": "sports",
    "Arts & Hobbies": "musicart",
    "Holidays": "party",
    "Countries": "countries",
    "Tech": "tech",
    "Online & Media": "online",
    "Big Ideas": "bigideas",
    "ASL Phrases": "sayings",
}


def parse_display_overrides() -> dict[str, str]:
    text = MODELS_SWIFT.read_text(encoding="utf-8")
    block = re.search(
        r'private static let overrides: \[String: String\] = \[(.*?)\]',
        text,
        re.S,
    )
    if not block:
        return {}
    pairs = re.findall(r'"([^"]+)":\s*"([^"]+)"', block.group(1))
    return dict(pairs)


def default_display(word_id: str) -> str:
    spaced = word_id.replace("_", " ").replace("-", " ")
    return " ".join(p[:1].upper() + p[1:].lower() for p in spaced.split())


def parse_categories() -> list[tuple[str, str, str | None, list[str]]]:
    swift = SIGNS_SWIFT.read_text(encoding="utf-8")
    block = re.search(
        r'let entries: \[\(String, String, String, String\?, \[String\]\)\] = \[(.*?)\]\s+return entries',
        swift,
        re.S,
    )
    if not block:
        raise SystemExit("Could not find SignCategory entries in SignsTabView.swift")

    entry_re = re.compile(
        r'\("([^"]+)",\s*"([^"]+)",\s*"[^"]+",\s*(?:nil|"([^"]*)"),\s*\[([^\]]*)\]\)'
    )
    entries: list[tuple[str, str, str | None, list[str]]] = []
    for line in block.group(1).split("\n"):
        line = line.strip().rstrip(",")
        if not line.startswith("("):
            continue
        match = entry_re.search(line)
        if not match:
            raise SystemExit(f"Unparsed category line: {line[:120]}")
        cid, title, icon, words_blob = match.group(1), match.group(2), match.group(3), match.group(4)
        words = re.findall(r'"([^"]+)"', words_blob)
        entries.append((cid, title, icon, words))
    return entries


def mascot_for(title: str, icon_asset: str | None) -> str:
    if icon_asset:
        return icon_asset
    return CATEGORY_MASCOT.get(title, "")


def main() -> None:
    overrides = parse_display_overrides()
    categories = parse_categories()

    rows: list[dict[str, str]] = []
    for cid, title, icon, words in categories:
        mascot = mascot_for(title, icon)
        for word_id in words:
            rows.append(
                {
                    "category_id": cid,
                    "category_title": title,
                    "mascot_name": mascot,
                    "word_id": word_id,
                    "word_display": overrides.get(word_id, default_display(word_id)),
                }
            )

    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "category_id",
                "category_title",
                "mascot_name",
                "word_id",
                "word_display",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    lines = [
        "# Signs dictionary — words by category",
        "",
        "Source: `ASL/Tabs/SignsTabView.swift` (`SignCategory.all`).",
        "Mascot names are the asset names used in `ASLUnitMascot` (e.g. `greetings`, `mealtime`).",
        "",
        "## Category index",
        "",
        "| Category | Mascot | Word count |",
        "| --- | --- | ---: |",
    ]
    for cid, title, icon, words in categories:
        mascot = mascot_for(title, icon)
        lines.append(f"| {title} | `{mascot}` | {len(words)} |")

    lines.append("")
    for cid, title, icon, words in categories:
        mascot = mascot_for(title, icon)
        lines.append(f"## {title}")
        lines.append("")
        lines.append(f"**Mascot:** `{mascot}`  ")
        lines.append(f"**Category id:** `{cid}`")
        lines.append("")
        for word_id in words:
            display = overrides.get(word_id, default_display(word_id))
            lines.append(f"- {display} (`{word_id}`)")
        lines.append("")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")

    unique_words = len({r["word_id"] for r in rows})
    print(f"Wrote {OUT_CSV}")
    print(f"Wrote {OUT_MD}")
    print(f"{len(categories)} categories, {len(rows)} rows, {unique_words} unique words")


if __name__ == "__main__":
    main()
