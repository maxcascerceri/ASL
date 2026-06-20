#!/usr/bin/env python3
"""Validate path medal specs embedded in ASLMedalCatalog.swift."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "ASL" / "Profile" / "ASLMedalCatalog.swift"
CURRICULUM_PATH = REPO_ROOT / "scripts" / "curriculum.json"


def extract_path_medal_specs(source: str) -> list[dict]:
    """Parse PathMedalSpec entries from Swift source (lightweight regex)."""
    block_match = re.search(
        r"private static let pathMedalSpecs.*?=\s*\[(.*?)\n\s*\]",
        source,
        re.DOTALL,
    )
    if not block_match:
        raise SystemExit("Could not find pathMedalSpecs in ASLMedalCatalog.swift")

    block = block_match.group(1)
    entries = re.findall(
        r'PathMedalSpec\s*\(\s*'
        r'id:\s*"([^"]+)".*?'
        r'phaseKey:\s*"([^"]+)".*?'
        r'phaseTitle:\s*"([^"]+)".*?'
        r'paletteIndex:\s*(\d+).*?'
        r'unitIds:\s*\[(.*?)\]',
        block,
        re.DOTALL,
    )

    specs = []
    for medal_id, phase_key, phase_title, palette_index, unit_ids_raw in entries:
        unit_ids = re.findall(r'"([^"]+)"', unit_ids_raw)
        specs.append(
            {
                "id": medal_id,
                "phaseKey": phase_key,
                "phaseTitle": phase_title,
                "paletteIndex": int(palette_index),
                "unitIds": unit_ids,
            }
        )
    return specs


def load_curriculum_unit_ids() -> set[str]:
    import json

    data = json.loads(CURRICULUM_PATH.read_text(encoding="utf-8"))
    units = data["paths"][0]["units"]
    return {
        unit["id"]
        for unit in units
        if not unit.get("isReview", False)
    }


def main() -> int:
    source = CATALOG_PATH.read_text(encoding="utf-8")
    specs = extract_path_medal_specs(source)
    curriculum_units = load_curriculum_unit_ids()

    phase_counts: Counter[str] = Counter()
    all_units: list[str] = []

    for spec in specs:
        phase_counts[spec["phaseKey"]] += 1
        all_units.extend(spec["unitIds"])

    errors: list[str] = []

    if len(specs) != 24:
        errors.append(f"Expected 24 path medals, found {len(specs)}")

    unit_counter = Counter(all_units)
    duplicates = [uid for uid, count in unit_counter.items() if count > 1]
    if duplicates:
        errors.append(f"Duplicate unit IDs: {sorted(duplicates)}")

    if len(set(all_units)) != 38:
        errors.append(f"Expected 38 unique units, found {len(set(all_units))}")

    missing = curriculum_units - set(all_units)
    extra = set(all_units) - curriculum_units
    if missing:
        errors.append(f"Units missing from medals: {sorted(missing)}")
    if extra:
        errors.append(f"Unknown unit IDs in medals: {sorted(extra)}")

    for phase, count in sorted(phase_counts.items()):
        if count < 3 or count % 3 != 0:
            errors.append(f"Phase {phase}: {count} medals (need multiple of 3, min 3)")

    if errors:
        print("Medal catalog validation FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("Medal catalog validation passed.")
    print(f"  Path medals: {len(specs)}")
    print(f"  Phases: {len(phase_counts)}")
    for phase, count in phase_counts.items():
        title = next(s["phaseTitle"] for s in specs if s["phaseKey"] == phase)
        print(f"    {title}: {count} medals")
    return 0


if __name__ == "__main__":
    sys.exit(main())
