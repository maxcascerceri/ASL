#!/usr/bin/env python3
"""Generate ASLTipCatalog in ASL/Lessons/ASLTipStepView.swift from asl_tips_catalog.py."""

from __future__ import annotations

import re
from pathlib import Path

from asl_tips_catalog import ASL_TIPS_CATALOG


def swift_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def generate_tip_lines() -> list[str]:
    lines = ["    static let all: [Tip] = ["]
    for tip in ASL_TIPS_CATALOG:
        word_id = tip.get("wordId", "")
        text = swift_escape(tip["text"])
        if word_id:
            word_id_arg = f'wordId: "{word_id}"'
        else:
            word_id_arg = "wordId: nil"
        lines.append(
            f'        Tip(id: "{tip["id"]}", text: "{text}", {word_id_arg}),'
        )
    lines.append("    ]")
    return lines


def main() -> None:
    repo = Path(__file__).resolve().parent.parent
    swift_path = repo / "ASL" / "Lessons" / "ASLTipStepView.swift"
    content = swift_path.read_text(encoding="utf-8")
    replacement = "\n".join(generate_tip_lines())
    updated, count = re.subn(
        r"    static let all: \[Tip\] = \[\n.*?\n    \]",
        replacement,
        content,
        count=1,
        flags=re.DOTALL,
    )
    if count != 1:
        raise SystemExit(f"Could not find ASLTipCatalog.all block in {swift_path}")
    swift_path.write_text(updated, encoding="utf-8")
    print(f"Updated {swift_path} ({len(ASL_TIPS_CATALOG)} tips)")


if __name__ == "__main__":
    main()
