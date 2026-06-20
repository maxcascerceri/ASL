#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIREBASE_PROJECT_ID:-asl-app-718bf}"
SERVICE_ACCOUNT="${FIREBASE_SERVICE_ACCOUNT:-$HOME/.firebase-keys/asl-admin.json}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/deploy_curriculum.sh [--dry-run] [--project-id PROJECT_ID] [--service-account PATH]

Regenerates scripts/curriculum.json, verifies that it contains the mixed-module
stone schema, then imports it to Firestore from this local checkout.

Environment overrides:
  FIREBASE_PROJECT_ID       Firebase project id (default: asl-app-718bf)
  FIREBASE_SERVICE_ACCOUNT  Firebase Admin SDK JSON path
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --project-id)
      PROJECT_ID="${2:?Missing value for --project-id}"
      shift 2
      ;;
    --service-account)
      SERVICE_ACCOUNT="${2:?Missing value for --service-account}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

python3 scripts/generate_curriculum_v4.py
bash scripts/build_bundled_media.sh --full

python3 - <<'PY'
import json
from pathlib import Path

path = Path("scripts/curriculum.json")
data = json.loads(path.read_text(encoding="utf-8"))
lesson = data["paths"][0]["units"][0]["lessons"][0]

errors = []
if lesson.get("sortOrder") != 1:
    errors.append(f"first sortOrder is {lesson.get('sortOrder')!r}")
if lesson.get("type") != "module":
    errors.append(f"first type is {lesson.get('type')!r}")
if not lesson.get("displayTitle"):
    errors.append("first lesson is missing displayTitle")
if not lesson.get("steps"):
    errors.append("first lesson has no steps")

stone4 = next(
    (
        l
        for curriculum_path in data.get("paths", [])
        for unit in curriculum_path.get("units", [])
        for l in unit.get("lessons", [])
        if l.get("sortOrder") == 4 and l.get("type") == "module"
    ),
    None,
)
stone1 = data["paths"][0]["units"][0]["lessons"][0]
stone1_bursts = sum(
    1 for step in stone1.get("steps", []) if step.get("kind") == "speedBurst"
)
if stone1_bursts:
    errors.append(f"stone 1 has {stone1_bursts} speedBurst step(s)")

lessons = [
    lesson
    for curriculum_path in data.get("paths", [])
    for unit in curriculum_path.get("units", [])
    for lesson in unit.get("lessons", [])
]
non_modules = [lesson["id"] for lesson in lessons if lesson.get("type") != "module" or not lesson.get("steps")]
if non_modules:
    errors.append(f"{len(non_modules)} lessons are missing module steps")

if errors:
    raise SystemExit("Refusing to import stale curriculum: " + "; ".join(errors))

print(f"Verified module curriculum: {len(lessons)} lessons")
print(
    f"First lesson: {lesson['title']} / displayTitle={lesson.get('displayTitle')!r} "
    f"/ {lesson['type']} / {len(lesson['steps'])} steps"
)
PY

python3 scripts/validate_asl_tips.py
python3 scripts/validate_curriculum.py

IMPORT_ARGS=(
  scripts/import_curriculum.py
  scripts/curriculum.json
  --project-id "$PROJECT_ID"
)

if [[ -f "$SERVICE_ACCOUNT" ]]; then
  IMPORT_ARGS+=(--service-account "$SERVICE_ACCOUNT")
elif [[ "$DRY_RUN" != "1" ]]; then
  echo "Service account not found at: $SERVICE_ACCOUNT" >&2
  echo "Set FIREBASE_SERVICE_ACCOUNT or pass --service-account PATH." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  IMPORT_ARGS+=(--dry-run)
else
  IMPORT_ARGS+=(--prune)
fi

python3 "${IMPORT_ARGS[@]}"

if [[ "$DRY_RUN" != "1" ]]; then
  python3 - <<PY
import firebase_admin
from firebase_admin import credentials, firestore

project_id = "$PROJECT_ID"
service_account = "$SERVICE_ACCOUNT"

if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(service_account), {"projectId": project_id})

doc = (
    firestore.client()
    .collection("paths").document("path1")
    .collection("units").document("p1-u01")
    .collection("lessons").document("p1-u01-l1")
    .get()
)
data = doc.to_dict() or {}
print("Firestore verification:")
print("  title:", data.get("title"))
print("  type:", data.get("type"))
print("  steps:", len(data.get("steps", [])))
print("  first step:", (data.get("steps") or [{}])[0].get("kind"))
PY
fi
