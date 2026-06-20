#!/usr/bin/env python3
"""Validate home-path unit → mascot asset mappings in ASLUnitMascot.swift."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MASCOT_SWIFT = REPO_ROOT / "ASL" / "ASLUnitMascot.swift"
ASSETS_DIR = REPO_ROOT / "ASL" / "Assets.xcassets"
DATA_MODULE = REPO_ROOT / "scripts" / "curriculum_v5_data.py"


def load_live_units() -> list[tuple[str, str]]:
    """Return (unit_id, title) for non-review teaching units in home-path order."""
    source = DATA_MODULE.read_text(encoding="utf-8")
    block = re.search(r"UNIT_SPECS:.*?=\s*\[(.*?)\n\]", source, re.DOTALL)
    if not block:
        raise SystemExit("Could not find UNIT_SPECS in curriculum_v5_data.py")

    units: list[tuple[str, str]] = []
    for unit_id, title in re.findall(
        r'\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,',
        block.group(1),
    ):
        units.append((unit_id, title))
    if not units:
        raise SystemExit("Could not parse UNIT_SPECS entries from curriculum_v5_data.py")
    return units


def parse_by_unit_id(source: str) -> dict[str, str]:
    match = re.search(
        r"private static let byUnitId: \[String: String\] = \[(.*?)\n    \]",
        source,
        re.DOTALL,
    )
    if not match:
        raise SystemExit("Could not find byUnitId in ASLUnitMascot.swift")

    mapping: dict[str, str] = {}
    for unit_id, asset in re.findall(r'"([^"]+)":\s*"([^"]+)"', match.group(1)):
        mapping[unit_id] = asset
    return mapping


def list_mascot_assets() -> set[str]:
    names: set[str] = set()
    if not ASSETS_DIR.is_dir():
        return names
    for path in ASSETS_DIR.iterdir():
        if path.suffix == ".imageset" or path.name.endswith(".imageset"):
            names.add(path.name.removesuffix(".imageset"))
    return names


def main() -> int:
    live_units = load_live_units()
    live_ids = {unit_id for unit_id, _ in live_units}
    swift_source = MASCOT_SWIFT.read_text(encoding="utf-8")
    by_unit_id = parse_by_unit_id(swift_source)
    assets = list_mascot_assets()

    errors: list[str] = []
    asset_to_units: dict[str, list[str]] = {}

    print(f"{'unit_id':<22} {'title':<28} mascot")
    print("-" * 72)
    for unit_id, title in live_units:
        asset = by_unit_id.get(unit_id)
        print(f"{unit_id:<22} {title:<28} {asset or '—'}")
        if not asset:
            errors.append(f"Missing mascot for live unit {unit_id} ({title})")
        else:
            asset_to_units.setdefault(asset, []).append(unit_id)
            if asset not in assets:
                errors.append(
                    f"Mascot asset '{asset}' for {unit_id} not found in Assets.xcassets"
                )

    for unit_id in sorted(by_unit_id):
        if unit_id not in live_ids:
            errors.append(f"Stale byUnitId entry for retired/missing unit {unit_id}")

    dupes = {asset: ids for asset, ids in asset_to_units.items() if len(ids) > 1}
    for asset, ids in sorted(dupes.items()):
        errors.append(f"Duplicate mascot '{asset}' assigned to: {', '.join(ids)}")

    mapped_ids = set(by_unit_id)
    if len(mapped_ids) != len(live_ids):
        errors.append(
            f"byUnitId has {len(mapped_ids)} entries; expected {len(live_ids)} live units"
        )

    print()
    print(f"Live units: {len(live_units)}")
    print(f"byUnitId entries: {len(by_unit_id)}")
    print(f"Unique mascots used: {len(asset_to_units)}")
    if dupes:
        print(f"Duplicates: {len(dupes)}")

    if errors:
        print("\nERRORS:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("\nMascot catalog OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
