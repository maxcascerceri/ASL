# ASL Firebase Pilot Scripts

These scripts prepare and upload a small Firebase pilot before scaling to every ASL word. They auto-detect the CSV file and adapt to either of the two real-world layouts of the American Sign Language Dataset:

- README layout: columns `word`, `video_path`, where the path includes the part folder.
- AslenseDataset layout: columns `word`, `videos`, where only the filename is provided and videos live across `part_1` to `part_11`.

## 1. Prepare a pilot manifest

Run this from Colab or a machine that can access the downloaded dataset folder:

```bash
python scripts/prepare_asl_pilot.py "/content/drive/MyDrive/asl_dataset" \
  --max-words 50 \
  --videos-per-word 4 \
  --output selected_videos.json
```

If the CSV is not auto-detected, point at it explicitly:

```bash
python scripts/prepare_asl_pilot.py "/content/drive/MyDrive/asl_dataset" \
  --csv "AslenseDataset.csv" \
  --max-words 50 \
  --videos-per-word 4 \
  --output selected_videos.json
```

The script indexes every video under part folders, validates rows in the CSV, and chooses the smallest files per word for a fast first pilot.

## 2. Install upload dependency

```bash
pip install firebase-admin
```

## 3. Filmmaker folders (Dropbox → Firebase)

After downloading a filmmaker’s folder (e.g. `~/Desktop/elijahASL`):

```bash
cd scripts

# Build manifest (maps display filenames → wordId)
python3 prepare_filmed_videos.py ~/Desktop/elijahASL \
  --assignment filming-assignments/Elijah.csv \
  --filmmaker Elijah \
  --output elijah_videos.json

# Preview uploads
python3 upload_firebase_pilot.py elijah_videos.json \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json \
  --dry-run

# Upload (Storage + Firestore videos subcollection)
python3 upload_firebase_pilot.py elijah_videos.json \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json
```

`prepare_filmed_videos.py` reads `curriculum-words-and-phrases.csv`, resolves Dropbox-style names (curly quotes, lowercase phrases, typos), and when multiple takes exist picks the clip that matches the sign's **primary unit** (e.g. directional `left` for Directions, mealtime `full` for Mealtime).

**Combined Ariel + Victoria folder** (one upload batch, no filmmaker split):

```bash
python3 prepare_filmed_videos.py ~/Desktop/victoriaarielsigns \
  --combined \
  --filmmaker VictoriaAriel \
  --output victoria_ariel_videos.json

python3 upload_firebase_pilot.py victoria_ariel_videos.json \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json
```

The manifest lists `pending` signs still to film (10 as of last check) and `selectionLog` for duplicate takes. Re-run after adding videos; only pending `wordId`s need new files.

`upload_firebase_pilot.py` also uploads `poster_001.jpg` per sign (ffmpeg frame at 0.15s) for fast dictionary grid thumbnails.

**Backfill posters** for videos uploaded before poster support:

```bash
python3 backfill_poster_images.py \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json \
  --dry-run

python3 backfill_poster_images.py \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json
```

Requires `ffmpeg` on PATH (or `pip install imageio-ffmpeg`).

**Canonical URL audit** (videos + full posters; add `--include-thumbs` after thumb backfill):

```bash
python3 audit_canonical_media_urls.py --sample 20
python3 audit_canonical_media_urls.py
```

**Grid thumb backfill** (`poster_thumb_360.jpg` primary grid asset; `--force` to refresh):

```bash
python3 backfill_poster_thumbs.py --thumb-size 360 --dry-run
python3 backfill_poster_thumbs.py --thumb-size 360
```

**Backfill Firestore `posterStoragePath`** on `words/{id}` (optional metadata enrichment):

```bash
python3 backfill_poster_storage_paths.py \
  --project-id asl-app-718bf \
  --service-account ~/.firebase-keys/asl-admin.json \
  --dry-run

python3 backfill_poster_storage_paths.py \
  --project-id asl-app-718bf \
  --service-account ~/.firebase-keys/asl-admin.json
```

Repeat with a single `filming-assignments/Jared.csv` for Jared's folder when ready.

## 4. Purge legacy pilot videos (keep filmmaker uploads)

After filmmaker batches are uploaded, remove old dataset/pilot clips for every
`wordId` **not** in the keep manifests. Curriculum (`paths/`) and parent
`words/{id}` stubs stay; only Storage blobs and `words/{id}/videos/*` are removed.

Default keep list = union of `elijah_videos.json` + `victoria_ariel_videos.json`
(450 signs). When Jared is uploaded, add his manifest:

```bash
cd scripts

# Preview
python3 purge_non_filmed_videos.py \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json \
  --keep-manifest elijah_videos.json \
  --keep-manifest victoria_ariel_videos.json \
  --keep-manifest jared_videos.json \
  --dry-run

# Execute (writes purge_non_filmed_videos_log.json)
python3 purge_non_filmed_videos.py \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account ~/.firebase-keys/asl-admin.json \
  --execute
```

Re-run `--dry-run` until "Will purge media for: 0 word IDs".

## 5. Upload the pilot

Use a Firebase service account JSON or application default credentials:

```bash
python scripts/upload_firebase_pilot.py selected_videos.json \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --service-account path/to/service-account.json
```

For a no-write preview:

```bash
python scripts/upload_firebase_pilot.py selected_videos.json \
  --project-id asl-app-718bf \
  --bucket asl-app-718bf.firebasestorage.app \
  --dry-run
```

## Firestore shape

The iOS shell reads:

```text
words/{wordId}
words/{wordId}/videos/{videoId}

paths/{pathId}
paths/{pathId}/units/{unitId}
paths/{pathId}/units/{unitId}/lessons/{lessonId}
```

Video files are uploaded to:

```text
asl-videos/{wordId}/{videoId}.mp4
```

## 6. Upload the curriculum

The lesson plan (paths, units, lessons) is in `curriculum.json` and uploads to Firestore independently of the video upload. Safe to run in parallel with the video upload because it writes to a different collection (`paths`).

For day-to-day lesson-flow tinkering, prefer the one-command local deploy. It
regenerates `curriculum.json`, verifies that the first lesson is the mixed
module shape (`Learn the Set`, `type: "module"`, first step `teach`), then
imports the exact local file to Firestore. This avoids stale Cloud Shell uploads.

One-time credential setup:

1. In Firebase Console, open Project settings > Service accounts.
2. Generate a new private key for `asl-app-718bf`.
3. Save it outside the repo:

```bash
mkdir -p ~/.firebase-keys
mv ~/Downloads/asl-app-718bf-firebase-adminsdk-*.json ~/.firebase-keys/asl-admin.json
chmod 600 ~/.firebase-keys/asl-admin.json
```

Deploy from this checkout:

```bash
scripts/deploy_curriculum.sh
```

Safe local preview (does not contact Firestore):

```bash
scripts/deploy_curriculum.sh --dry-run
```

If the key lives somewhere else:

```bash
FIREBASE_SERVICE_ACCOUNT=/path/to/admin.json scripts/deploy_curriculum.sh
```

Dry-run preview:

```bash
python scripts/import_curriculum.py scripts/curriculum.json \
  --project-id asl-app-718bf \
  --dry-run
```

Real upload:

```bash
python scripts/import_curriculum.py scripts/curriculum.json \
  --project-id asl-app-718bf \
  --service-account path/to/service-account.json
```

Prune stale data (deletes any `paths`, `units`, or `lessons` documents in Firestore that no longer appear in `curriculum.json`):

```bash
python scripts/import_curriculum.py scripts/curriculum.json \
  --project-id asl-app-718bf \
  --service-account path/to/service-account.json \
  --prune
```

`--prune` does not touch `words/` or Firebase Storage. Without `--prune` the script is purely additive (merge writes) and never deletes anything.

## 5b. Firebase security rules (required for Home + videos)

**Storage:** Sign videos stop loading when the default test rule expires (`request.time < timestamp.date(2026, 6, 5)`). Deploy permanent read access:

```bash
python3 scripts/deploy_storage_rules.py
```

Rules live in `storage.rules` at the repo root (public read on `asl-videos/**` only).

## 5c. Firestore security rules (required for Home)

The iOS app reads `paths`, `units`, `lessons`, `words`, and `videos` without signing in. If Home is blank but curriculum deploy succeeded, the client is usually blocked by Firestore rules.

Rules live in `firestore.rules` at the repo root.

**If logs show `Missing or insufficient permissions`**, the usual cause is expired Firebase “test mode” rules (`request.time < timestamp.date(2026, 6, 5)`). Redeploy:

```bash
python3 scripts/deploy_firestore_rules.py
```

Uses `~/.firebase-keys/asl-admin.json` by default. Or with the Firebase CLI:

```bash
firebase deploy --only firestore:rules --project asl-app-718bf
```

## 6. Curriculum schema (v5.5.0 — longer stones, nine-word sets, stone 1 variety)

`curriculum.json` is generated by `generate_curriculum_v4.py`. Unit metadata
and `PHRASE_COMPONENTS` live in `curriculum_v5_data.py`; sentence content is in
`generate_curriculum_v4.py`. Regenerate and validate:

```bash
cd scripts
python3 validate_asl_tips.py
python3 generate_curriculum_v4.py
python3 validate_curriculum.py
python3 validate_mascot_catalog.py
python3 generate_stone_media_manifest.py
python3 generate_asl_tip_catalog_swift.py
```

Each unit has **three module stones** plus optional **phase review** lessons.
Pedagogy rules enforced at generation time:

- New signs use an explicit **`teach`** step followed by a recognition confirm within two steps. Intro confirms rotate **50% `wordPickVideo` (Pick Out)**, **25% `watchChoose`**, **25% `translationChoose`**. Stone 1 includes **two discretionary `yourTurn`** steps; stone 2 includes **one**; every **Watch this phrase** teach is followed immediately by **Your Turn** for that phrase. Stone 1 targets **~8** new atomic signs per unit (down from 10); Stone 3 may introduce **up to 3** new atomic signs from its stone subset per lesson; phrase blocks on stone 3 still teach components and phrases assigned to that stone.
- Each atomic word is taught at most once (`teach` never repeats for the same word).
- **One recognition channel per word per stone** — never both `watchChoose` and `wordPickVideo` for the same answer; never both `watchChoose` and `translationChoose` for the same answer.
- Second exposure on a word must use a **different UI channel** (Pick Out, `fillSlot`, or `matchPairs` — not a second sign-to-word pick).
- No back-to-back steps in the same quiz family (`watchChoose`/`translationChoose` vs `wordPickVideo`).
- No back-to-back **new-sign introductions** on any stone (each teach or first-exposure pick is followed by a recognition confirm before the next new sign).
- At most **two** consecutive teach → intro-confirm pairs (e.g. teach then "What sign is this?") before a varied review step.
- After each **`teach`**, at most **2 of the next 3** graded exercises may use that sign as the correct answer (intro confirm counts toward the window).
- Graded answers must already be in the cumulative `taughtSet`; distractors may be untaught or from earlier units.
- Module stones target **22–34 total steps** with **≥10 unique graded answer words** on stone 1 (subset size per stone in `UNIT_STONE_WORD_SUBSETS`).
- Answer spacing: max **2** graded correct answers per word per lesson; stone 1 min gap **6** graded steps between repeats (stones 2–3 gap **4**). Spacing runs as the **final** `finish()` pass after top-up.
- Stone 1 mixes **`wordPickVideo` (Pick Out)**, **`watchChoose`**, **`translationChoose`**, **`matchPairs`**, and **`fillSlot`**. Minimum per lesson: **5 Pick Out**, **2 matchPairs**, **24 steps**. Combined recognition (all three pick kinds) capped at **68% / 62% / 55%** for stones 1–3.
- Phrase pedagogy is **teach components → `signSequence`** on the learning stone (`_append_phrase_block`); **`phraseSlot`** review alternates with `signSequence` on **stones 2–3** for phrases already sequenced earlier. Filmed phrase units must emit `signSequence` on at least one stone 1–3 lesson.
- **`speedBurst` is removed**; stone 3 ends on **`matchPairs`** when possible and caps new atomic subset **`teach`** steps at **3** per lesson (phrase component teaches are separate).
- Max **2 discretionary `yourTurn` steps per unit** (stones 1–2 only), plus **Your Turn** after every phrase teach.

| Stone | Title               | Emotional arc (summary)                                |
| ----- | ------------------- | ------------------------------------------------------ |
| 1     | Learn & Lock In     | teach → Pick Out confirm → recognition mix → yourTurn (×2) → match → context → phrase sprinkle |
| 2     | Use It              | warm-up → teach → confirm → phrase/context → yourTurn → fillSlot → match |
| 3     | Challenge Mix       | warm-up → up to 2 new teaches → cross-unit review → match capstone → mixed challenge |

**Target graded mix (module stones, approximate):** combined recognition ≤68% / 62% / 55%; **`wordPickVideo` (Pick Out) minimum 5 / 3 / 5** per stone; **`matchPairs` minimum 2 / 2 / 3**; `yourTurn` on stones 1–2 only; context cluster (`fillSlot` + `signSequence` + `phraseSlot`) ≥5% / 8% / 8%. Pick Out uses two stacked video cards with prompt **"Pick out [Word]."**

**Phase review** lessons reuse the phrase recipe: `signSequence` + `phraseSlot` per phrase (no `signSequence` → `watchChoose` pairs for the same phrase).

Phrase sign order is authored in `PHRASE_COMPONENTS` (one ordered word-id list
per phrase in `PHRASE_IDS`).

### Lesson fields

All lessons carry `id`, `title`, `type`, `sortOrder`, `wordIds`, and `steps`.
Supported module step kinds:

- `teach`: `{ kind, wordId, title, prompt }` — passive intro; confirm quiz follows
- `watchChoose`: `{ kind, answerWordId, distractorWordIds, choiceCount, prompt }`
- `translationChoose`: same shape; allowed on stone 1+; meaning-first UI in app
- `wordPickVideo`: **Pick Out** — two stacked tappable videos; prompt `"Pick out [Word]."` (primary variety break vs single-video picks)
- `fillSlot`: `{ kind, sentenceBefore, sentenceAfter, answerWordId, distractorWordIds }`
- `matchPairs`: `{ kind, pairWordIds, prompt }` (2–4 pairs from words introduced on prior stones or earlier in the same stone)
- `signSequence`: `{ kind, wordId, sequenceWordIds, distractorWordIds, prompt }`
- `phraseSlot`: `{ kind, wordId, sequenceWordIds, slotIndex, answerWordId, distractorWordIds, prompt }`

Legacy kinds (`watchPick2`, `watchPick4`, `fillGap`, `speedBurst`, `selfSign`) are rejected by the validator and stripped from the iOS module pipeline.

Fill-slot sentences follow the short-line target (about five words total).
Distractors may include vocabulary from earlier units on the home path.
For `watchChoose` and `translationChoose`, the generator picks distractors from
the same semantic category as the answer when enough peers exist in the pool
(see `SEMANTIC_DISTRACTOR_CATEGORIES` in `curriculum_v5_data.py`); otherwise it
falls back to positional rotation. The app mirrors this for runtime top-up via
`ASLSemanticDistractors.swift`.

### Sign equivalence (pronoun aliases)

Some English glosses share one ASL production and one filmed clip (e.g. **I / Me**,
**He / Him**). Authoring uses a **canonical** `wordId` for teaches, video playback,
Pick Out, and match pairs; **alias** ids appear only where English grammar differs
(stone 3 `fillSlot` prompts on **You & Me**).

| Aliases | Canonical |
| ------- | --------- |
| me | i |
| us | we |
| him | he |
| her | she |
| them | they |
| mine | my |
| yours | your |
| ours | our |

Python: `SIGN_ALIAS_TO_CANONICAL`, `same_sign()`, `filter_distinct_sign_words()` in
`curriculum_v5_data.py`; `validate_same_sign_exercises()` rejects alias teaches and
same-sign distractor pairs. iOS: `SignEquivalence.swift` and canonical resolution in
`BundledSignMedia.swift`; the dictionary groups pronouns into 11 cards with alias-aware
search.

**p1-u03 You & Me** keeps 11 canonical signs across three stones: stone 1 refreshes
**i / you / my / your** (from p1-u01) and teaches **we**; stone 2 adds **he / she /
they / his / their / our**; stone 3 mixes review with English-only alias `fillSlot`
grammar. Pinned `aslTip` steps after each new teach explain the shared-sign pairs.

### Migration from v3

v3 used `types: [String]` for tagging. v4 replaces it with a single `type:
String`; the current module schema sets that value to `"module"` and puts the
actual learning sequence in `steps`. The import script writes the new shape; run
`import_curriculum.py ... --prune` to delete lesson docs whose IDs are no longer
present.
