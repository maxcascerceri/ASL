#!/usr/bin/env python3
"""Upsert Firestore word stubs for every ID referenced in curriculum.json.

Creates or merges `words/{id}` with videoCount 0 so lessons can load titles and
show blank video containers before Storage uploads complete.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from curriculum_v5_data import DISPLAY_OVERRIDES


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("curriculum", type=Path, help="Path to curriculum.json.")
    parser.add_argument("--project-id", required=True, help="Firebase project ID.")
    parser.add_argument("--service-account", type=Path, help="Optional Firebase service account JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned upserts without writing.")
    return parser.parse_args()


def initialize_firebase(project_id: str, service_account: Path | None):
    import firebase_admin
    from firebase_admin import credentials, firestore

    if firebase_admin._apps:
        return firestore.client()

    if service_account:
        credential = credentials.Certificate(service_account)
    else:
        credential = credentials.ApplicationDefault()

    firebase_admin.initialize_app(credential, {"projectId": project_id})
    return firestore.client()


def display_word(word_id: str) -> str:
    if word_id in DISPLAY_OVERRIDES:
        return DISPLAY_OVERRIDES[word_id]
    return re.sub(r"[_-]+", " ", word_id).title()


def collect_word_ids(curriculum: dict) -> set[str]:
    ids: set[str] = set()
    for path in curriculum.get("paths", []):
        for unit in path.get("units", []):
            for lesson in unit.get("lessons", []):
                ids.update(lesson.get("wordIds", []))
                for step in lesson.get("steps", []):
                    if word_id := step.get("wordId"):
                        ids.add(word_id)
                    if answer := step.get("answerWordId"):
                        ids.add(answer)
                    ids.update(step.get("distractorWordIds", []))
                    ids.update(step.get("pairWordIds", []))
    return ids


def main() -> None:
    args = parse_args()
    curriculum = json.loads(args.curriculum.read_text(encoding="utf-8"))
    word_ids = sorted(collect_word_ids(curriculum))

    print(f"Curriculum version: {curriculum.get('version', 'unknown')}")
    print(f"Unique word IDs: {len(word_ids)}")

    if args.dry_run:
        for word_id in word_ids[:20]:
            print(f"  {word_id} -> {display_word(word_id)}")
        if len(word_ids) > 20:
            print(f"  ... and {len(word_ids) - 20} more")
        return

    db = initialize_firebase(args.project_id, args.service_account)

    created = 0
    for word_id in word_ids:
        text = display_word(word_id)
        doc = {
            "text": text,
            "normalizedText": word_id,
            "videoCount": 0,
            "categoryIds": [],
            "published": True,
        }
        db.collection("words").document(word_id).set(doc, merge=True)
        created += 1

    print(f"Upserted {created} word stubs to Firestore.")


if __name__ == "__main__":
    main()
