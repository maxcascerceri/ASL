#!/usr/bin/env python3
"""Upload the ASL curriculum (paths, units, lessons) to Firestore.

Safe to run while video uploads are still in progress; this writes to the
`paths` collection only and does not touch `words` or Firebase Storage.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("curriculum", type=Path, help="Path to curriculum.json.")
    parser.add_argument("--project-id", required=True, help="Firebase project ID, for example asl-app-718bf.")
    parser.add_argument("--service-account", type=Path, help="Optional Firebase service account JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Preview write counts without contacting Firestore.")
    parser.add_argument(
        "--prune",
        action="store_true",
        help="Delete paths/units/lessons in Firestore that are not present in the curriculum file.",
    )
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


def main() -> None:
    args = parse_args()
    curriculum = json.loads(args.curriculum.read_text(encoding="utf-8"))

    paths = curriculum.get("paths", [])
    total_units = sum(len(path.get("units", [])) for path in paths)
    total_lessons = sum(
        len(unit.get("lessons", []))
        for path in paths
        for unit in path.get("units", [])
    )

    print(f"Curriculum version: {curriculum.get('version', 'unknown')}")
    print(f"Paths: {len(paths)}  Units: {total_units}  Lessons: {total_lessons}")

    if args.dry_run:
        for path in paths:
            print(f"- {path['id']} {path['title']} ({len(path['units'])} units)")
            for unit in path["units"]:
                print(f"    {unit['id']} {unit['title']} ({len(unit['lessons'])} lessons)")
        return

    db = initialize_firebase(args.project_id, args.service_account)

    written_paths = 0
    written_units = 0
    written_lessons = 0

    for path in paths:
        path_doc = {
            "title": path["title"],
            "tagline": path.get("tagline", ""),
            "color": path.get("color", "#22C55E"),
            "sortOrder": path.get("sortOrder", 0),
            "unlock": path.get("unlock", {"type": "always"}),
            "unitCount": len(path.get("units", [])),
            "published": True,
        }
        db.collection("paths").document(path["id"]).set(path_doc, merge=True)
        written_paths += 1

        for unit in path.get("units", []):
            unit_doc = {
                "pathId": path["id"],
                "title": unit["title"],
                "description": unit.get("description", ""),
                "badge": unit.get("badge", ""),
                "sortOrder": unit.get("sortOrder", 0),
                "mandatoryGateway": unit.get("mandatoryGateway", False),
                "isReview": unit.get("isReview", False),
                "isPhaseReview": unit.get("isPhaseReview", False),
                "isMilestone": unit.get("isMilestone", False),
                "evergreen": unit.get("evergreen", False),
                "lessonCount": len(unit.get("lessons", [])),
                "phaseKey": unit.get("phaseKey", ""),
                "phaseTitle": unit.get("phaseTitle", ""),
                "published": True,
            }
            unit_ref = (
                db.collection("paths")
                .document(path["id"])
                .collection("units")
                .document(unit["id"])
            )
            unit_ref.set(unit_doc, merge=True)
            written_units += 1

            for lesson in unit.get("lessons", []):
                lesson_doc = {
                    "pathId": path["id"],
                    "unitId": unit["id"],
                    "title": lesson["title"],
                    "type": lesson.get("type", ""),
                    "sortOrder": lesson.get("sortOrder", 0),
                    "wordIds": lesson.get("wordIds", []),
                    "wordCount": len(lesson.get("wordIds", [])),
                    "published": True,
                }
                if lesson.get("displayTitle"):
                    lesson_doc["displayTitle"] = lesson["displayTitle"]
                if "questions" in lesson:
                    lesson_doc["questions"] = lesson["questions"]
                if "steps" in lesson:
                    lesson_doc["steps"] = lesson["steps"]
                if "timePerQuestionMs" in lesson:
                    lesson_doc["timePerQuestionMs"] = lesson["timePerQuestionMs"]
                if "config" in lesson:
                    lesson_doc["config"] = lesson["config"]
                unit_ref.collection("lessons").document(lesson["id"]).set(lesson_doc, merge=True)
                written_lessons += 1

    deleted_paths = 0
    deleted_units = 0
    deleted_lessons = 0

    if args.prune:
        keep_path_ids = {path["id"] for path in paths}
        keep_units_by_path = {
            path["id"]: {unit["id"] for unit in path.get("units", [])}
            for path in paths
        }
        keep_lessons_by_unit = {
            (path["id"], unit["id"]): {lesson["id"] for lesson in unit.get("lessons", [])}
            for path in paths
            for unit in path.get("units", [])
        }

        for path_snap in db.collection("paths").stream():
            path_id = path_snap.id
            path_ref = db.collection("paths").document(path_id)

            if path_id not in keep_path_ids:
                for unit_snap in path_ref.collection("units").stream():
                    unit_ref = path_ref.collection("units").document(unit_snap.id)
                    for lesson_snap in unit_ref.collection("lessons").stream():
                        unit_ref.collection("lessons").document(lesson_snap.id).delete()
                        deleted_lessons += 1
                    unit_ref.delete()
                    deleted_units += 1
                path_ref.delete()
                deleted_paths += 1
                continue

            kept_units = keep_units_by_path.get(path_id, set())
            for unit_snap in path_ref.collection("units").stream():
                unit_id = unit_snap.id
                unit_ref = path_ref.collection("units").document(unit_id)

                if unit_id not in kept_units:
                    for lesson_snap in unit_ref.collection("lessons").stream():
                        unit_ref.collection("lessons").document(lesson_snap.id).delete()
                        deleted_lessons += 1
                    unit_ref.delete()
                    deleted_units += 1
                    continue

                kept_lessons = keep_lessons_by_unit.get((path_id, unit_id), set())
                for lesson_snap in unit_ref.collection("lessons").stream():
                    if lesson_snap.id not in kept_lessons:
                        unit_ref.collection("lessons").document(lesson_snap.id).delete()
                        deleted_lessons += 1

    print(
        f"Done. Wrote {written_paths} paths, {written_units} units, {written_lessons} lessons."
    )
    if args.prune:
        print(
            f"Pruned {deleted_paths} paths, {deleted_units} units, {deleted_lessons} lessons."
        )


if __name__ == "__main__":
    main()
