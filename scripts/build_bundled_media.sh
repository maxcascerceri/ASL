#!/usr/bin/env bash
# Regenerate manifests and optionally export bundled posters/videos for the iOS app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/scripts"

cd "$SCRIPTS"

python3 generate_filmed_sign_catalog.py
python3 generate_stone_media_manifest.py

if [[ "${1:-}" == "--full" ]]; then
  python3 transcode_mobile_videos.py --all-filmed --budget-mb 170 --force
  python3 export_bundled_posters_from_videos.py --force
  python3 validate_bundled_media_budget.py --max-mb 170
  echo "Bundled media exported to ASL/BundledMedia/"
else
  echo "Manifests updated. Run with --full to export posters and transcode bundle videos."
fi
