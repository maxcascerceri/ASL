#!/usr/bin/env python3
"""Scan curriculum.json for teach-before-quiz pedagogy violations."""

from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

from generate_curriculum_v4 import (
    RECOGNITION_KINDS,
    STONE_MID_YOUR_TURN,
    STONE_RECOGNITION_SHARE_CAP,
    STONE_REPETITION_RULES,
    _adjacent_graded_answer_conflict,
    _allows_teach_intro_confirm_pair,
    _graded_answer_word_ids,
    _graded_step_answer_tokens,
    _is_graded_exercise_step,
    _step_graded_answer_ids,
    repetition_rule,
)
from curriculum_v5_data import (
    DISPLAY_OVERRIDES,
    MIN_SIGNS_PER_STONE,
    PHRASE_COMPONENTS,
    PHRASE_FILL_SLOTS,
    PHRASE_IDS,
    PHRASE_SEQUENCE_UNITS,
    UNIT_SPECS,
    UNIT_STONE_WORD_SUBSETS,
    min_unique_answers_for_unit,
    semantic_distractor_peer_ids,
    stone1_review_candidates,
)

# Length targets mirror the generator (Universal Unit Framework).
STONE_MIN_STEPS = {1: 24, 2: 26, 3: 22}
STONE_MAX_STEPS = {1: 32, 2: 34, 3: 28}
MIN_UNIQUE_ANSWERS_PER_STONE = 10
CATEGORY_CHALLENGE_MIN_STEPS = 16
CATEGORY_CHALLENGE_MAX_STEPS = 24


def _midlesson_your_turn_count(steps: list[dict]) -> int:
    step_count = len(steps)
    if step_count < 4:
        return 0
    target = step_count // 2
    tolerance = max(3, step_count // 4)
    placed = 0
    for index, step in enumerate(steps):
        if step.get("kind") != "yourTurn":
            continue
        word_id = step.get("wordId")
        if not word_id:
            continue
        answered_before = any(
            word_id in _graded_answer_word_ids(prior) for prior in steps[:index]
        )
        if answered_before and abs(index - target) <= tolerance:
            placed += 1
    return placed

_MANIFEST_FILES = ("elijah_videos.json", "victoria_ariel_videos.json")
# Phrase exercises require the phrase clip; the answer video is shown on screen.
_PHRASE_VIDEO_KINDS = frozenset({"signSequence", "phraseSlot"})
# Steps that surface a sign video tied to a word id (main stage or choice tiles).
_ANSWER_VIDEO_KINDS = frozenset({
    "watchChoose",
    "translationChoose",
    "wordPickVideo",
    "watchPick2",
    "watchPick4",
    "watchThenPick",
    "meaningPick",
    "fillSlot",
    "fillGap",
    "aslTip",
    "matchPairs",
    "signSequence",
    "speedBurst",
})


def _load_available_video_ids() -> set[str]:
    available: set[str] = set()
    here = Path(__file__).resolve().parent
    for name in _MANIFEST_FILES:
        path = here / name
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        for entry in data.get("videos", []):
            if isinstance(entry, dict) and entry.get("wordId"):
                available.add(entry["wordId"])
    bundled_videos = here.parent / "ASL" / "BundledMedia" / "Videos"
    if bundled_videos.is_dir():
        for path in bundled_videos.glob("*.mp4"):
            available.add(path.stem)
    return available


AVAILABLE_VIDEO_IDS: set[str] = _load_available_video_ids()


def _distractor_pool(unit_words: list[str], prior_pool: list[str]) -> list[str]:
    return list(dict.fromkeys(unit_words + prior_pool))


def _step_answer_key(step: dict):
    """Representative correct-answer identity for variety checks (or None)."""
    kind = step.get("kind")
    if kind == "matchPairs":
        pairs = step.get("pairWordIds", [])
        return ("matchPairs", tuple(pairs)) if pairs else None
    if kind == "signSequence":
        return ("signSequence", step.get("wordId"))
    if kind == "phraseSlot":
        return ("phraseSlot", step.get("wordId"), step.get("slotIndex"))
    if kind in {"teach", "selfSign", "yourTurn", "aslTip"}:
        return None
    return step.get("answerWordId")


def validate_phrase_video_availability(data: dict) -> list[str]:
    """No-op: curriculum keeps unfilmed phrase steps; runtime shows coming soon."""
    _ = data
    return []


def _step_video_word_ids(step: dict) -> set[str]:
    """Word ids that must have a filmed video for this step to play correctly."""
    kind = step.get("kind")
    ids: set[str] = set()
    if kind not in _ANSWER_VIDEO_KINDS:
        return ids
    # Phrase order / missing-sign steps play the phrase clip; component tiles are text.
    if kind in {"signSequence", "phraseSlot"}:
        if word_id := step.get("wordId"):
            ids.add(word_id)
        return ids
    if answer := step.get("answerWordId"):
        ids.add(answer)
    if word_id := step.get("wordId"):
        ids.add(word_id)
    if phrase := step.get("phraseWordId"):
        ids.add(phrase)
    for wid in step.get("distractorWordIds", []):
        if kind == "wordPickVideo":
            ids.add(wid)
    for wid in step.get("pairWordIds", []):
        ids.add(wid)
    for wid in step.get("questionWordIds", []):
        ids.add(wid)
    for wid in step.get("sequenceWordIds", []):
        ids.add(wid)
    return ids


def validate_answer_video_availability(data: dict) -> list[str]:
    """Hard errors: quiz/teach steps must reference filmed sign videos.

    Skips when no filming manifest is present (running outside the repo)."""
    errors: list[str] = []
    if not AVAILABLE_VIDEO_IDS:
        return errors
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind not in _ANSWER_VIDEO_KINDS:
                        continue
                    missing = sorted(
                        wid for wid in _step_video_word_ids(step)
                        if wid not in AVAILABLE_VIDEO_IDS
                    )
                    if missing:
                        errors.append(
                            f"{lesson_id} step {index} ({kind}): "
                            f"missing filmed video for {', '.join(missing)}"
                        )
    return errors


def validate_no_adjacent_same_graded_answer(data: dict) -> list[str]:
    """Hard errors: no two consecutive graded exercises share a sign or phrase answer."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                for index in range(1, len(steps)):
                    prev, curr = steps[index - 1], steps[index]
                    if not _is_graded_exercise_step(prev) or not _is_graded_exercise_step(
                        curr
                    ):
                        continue
                    if not _adjacent_graded_answer_conflict(prev, curr):
                        continue
                    overlap = _graded_step_answer_tokens(prev) & _graded_step_answer_tokens(
                        curr
                    )
                    errors.append(
                        f"{lesson_id} step {index}: back-to-back graded answer "
                        f"{sorted(overlap)!r} ({prev.get('kind')} → {curr.get('kind')})"
                    )
    return errors


def validate_variety(data: dict) -> list[str]:
    """Warnings: no identical correct answer twice in a row, and no exercise
    type three times consecutively, within a lesson."""
    warnings: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                for i in range(1, len(steps)):
                    prev_key = _step_answer_key(steps[i - 1])
                    cur_key = _step_answer_key(steps[i])
                    if prev_key is not None and prev_key == cur_key:
                        warnings.append(
                            f"{lesson_id}: same correct answer twice in a row "
                            f"near index {i} ({cur_key})"
                        )
                for i in range(2, len(steps)):
                    a, b, c = steps[i - 2].get("kind"), steps[i - 1].get("kind"), steps[i].get("kind")
                    if a == b == c and a not in {"teach"}:
                        warnings.append(
                            f"{lesson_id}: exercise type {a} three times in a row "
                            f"near index {i}"
                        )
    return warnings


_GRADED_QUIZ_KINDS = frozenset({
    "watchChoose",
    "translationChoose",
    "fillSlot",
    "wordPickVideo",
    "fillGap",
    "meaningPick",
    "watchPick2",
    "watchPick4",
    "watchThenPick",
})


def _graded_answer_word_ids(step: dict) -> list[str]:
    kind = step.get("kind")
    if kind == "matchPairs":
        return list(step.get("pairWordIds") or [])
    if kind == "signSequence":
        phrase = step.get("wordId")
        return [phrase] if phrase else []
    if kind == "speedBurst":
        return list(step.get("questionWordIds") or [])
    if kind in _GRADED_QUIZ_KINDS:
        answer = step.get("answerWordId")
        return [answer] if answer else []
    return []


def validate_min_unique_answers_per_stone(
    data: dict, minimum: int = MIN_UNIQUE_ANSWERS_PER_STONE
) -> list[str]:
    """Each module stone must grade at least nine distinct answers when possible."""
    errors: list[str] = []
    spec_words = {spec[0]: spec[-1] for spec in UNIT_SPECS}
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            unit_words = spec_words.get(unit_id, unit.get("words") or [])
            unit_word_count = len(unit_words)
            required = (
                minimum
                if unit_word_count >= MIN_SIGNS_PER_STONE
                else min_unique_answers_for_unit(unit_word_count)
            )
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                sort_order = int(lesson.get("sortOrder") or 0)
                if sort_order not in {1, 2, 3}:
                    continue
                lesson_id = lesson.get("id", "?")
                if lesson_id.endswith("-review"):
                    continue
                steps = lesson.get("steps", [])
                unique = {
                    answer
                    for step in steps
                    for answer in _graded_answer_word_ids(step)
                }
                if sort_order == 1:
                    taught_count = len(
                        [
                            step
                            for step in steps
                            if step.get("kind") == "teach"
                            and step.get("wordId")
                            and step.get("wordId") not in PHRASE_IDS
                        ]
                    )
                    if taught_count:
                        required = min(required, taught_count)
                if len(unique) < required:
                    errors.append(
                        f"{lesson_id}: {len(unique)} unique graded answers "
                        f"(minimum {required})"
                    )
    return errors


def validate_answer_density(data: dict) -> tuple[list[str], list[str]]:
    """Hard errors for answer clustering in module stones."""
    errors: list[str] = []
    warnings: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                sort_order = int(lesson.get("sortOrder") or 0)
                if sort_order not in {1, 2, 3}:
                    continue
                lesson_id = lesson.get("id", "?")
                if lesson_id.endswith("-review"):
                    continue
                steps = lesson.get("steps", [])
                window = repetition_rule(sort_order, "density_window")
                max_in_window = repetition_rule(sort_order, "density_max_in_window")
                graded_indices = [
                    index
                    for index, step in enumerate(steps)
                    if _step_graded_answer_ids(step)
                ]
                for pos in range(1, len(graded_indices)):
                    index = graded_indices[pos]
                    prev_index = graded_indices[pos - 1]
                    prev_step = steps[prev_index]
                    curr_step = steps[index]
                    if _adjacent_graded_answer_conflict(prev_step, curr_step):
                        overlap = _graded_step_answer_tokens(prev_step) & _graded_step_answer_tokens(
                            curr_step
                        )
                        if overlap:
                            errors.append(
                                f"{lesson_id}: adjacent graded answer overlap "
                                f"{sorted(overlap)!r} near index {index}"
                            )
                for index, step in enumerate(steps):
                    answers = _step_graded_answer_ids(step)
                    if not answers:
                        continue
                    start = max(0, index - window + 1)
                    window_answers: list[str] = []
                    for i in range(start, index + 1):
                        window_answers.extend(_step_graded_answer_ids(steps[i]))
                    for answer in answers:
                        if window_answers.count(answer) > max_in_window:
                            errors.append(
                                f"{lesson_id}: answer {answer!r} appears "
                                f"{window_answers.count(answer)} times in {window} steps "
                                f"near index {index}"
                            )
    return errors, warnings


def validate_min_answer_gap(data: dict) -> list[str]:
    """Errors when graded answer tokens repeat within the stone gap."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                sort_order = int(lesson.get("sortOrder") or 0)
                if sort_order not in {1, 2, 3}:
                    continue
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                min_gap = repetition_rule(sort_order, "min_answer_gap")
                recent: list[frozenset[str]] = []
                for index, step in enumerate(steps):
                    if not _is_graded_exercise_step(step):
                        continue
                    if index > 0 and _allows_teach_intro_confirm_pair(steps[index - 1], step):
                        continue
                    answers = frozenset(_step_graded_answer_ids(step))
                    flat_recent = {token for group in recent for token in group}
                    if answers and answers & flat_recent:
                        errors.append(
                            f"{lesson_id}: answer tokens repeat within "
                            f"{min_gap} graded steps near index {index}: "
                            f"{sorted(answers & flat_recent)!r}"
                        )
                    recent = (recent + [answers])[-min_gap:]
    return errors


def validate_asl_tip_presence(data: dict) -> list[str]:
    """Warnings when a module stone omits the ASL tip rhythm break."""
    warnings: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            if unit.get("isReview"):
                continue
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                sort_order = int(lesson.get("sortOrder") or 0)
                if sort_order not in {1, 2, 3}:
                    continue
                kinds = {step.get("kind") for step in lesson.get("steps", [])}
                if "aslTip" not in kinds:
                    warnings.append(
                        f"{lesson.get('id', '?')}: stone {sort_order} missing aslTip step"
                    )
    return warnings


def validate_asl_tip_stone1(data: dict) -> list[str]:
    """Deprecated alias — kept for callers; use validate_asl_tip_presence."""
    return validate_asl_tip_presence(data)


def validate_lengths(data: dict) -> tuple[list[str], list[str]]:
    """Hard errors for module stone step counts; warnings for phase reviews."""
    errors: list[str] = []
    warnings: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            is_review = bool(unit.get("isReview"))
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                count = len(lesson.get("steps", []))
                if is_review:
                    lo = CATEGORY_CHALLENGE_MIN_STEPS
                    hi = CATEGORY_CHALLENGE_MAX_STEPS
                    label = "category challenge"
                    bucket = warnings
                else:
                    sort_order = int(lesson.get("sortOrder") or 0)
                    if sort_order not in STONE_MIN_STEPS:
                        continue
                    lo = STONE_MIN_STEPS[sort_order]
                    hi = STONE_MAX_STEPS[sort_order]
                    label = f"stone {sort_order}"
                    bucket = errors
                if count < lo or count > hi:
                    bucket.append(
                        f"{lesson_id}: {label} has {count} steps (target {lo}-{hi})"
                    )
    return errors, warnings


QUIZ_KINDS = frozenset(
    {"watchChoose", "translationChoose", "fillSlot", "wordPickVideo"}
)
SHAPE_BREAK_KINDS = frozenset(
    {"teach", "matchPairs", "signSequence", "speedBurst", "fillSlot", "wordPickVideo"}
)


def validate_semantic_distractors(data: dict) -> list[str]:
    """Soft warnings when watchChoose/translationChoose omit obvious category peers."""
    warnings: list[str] = []
    prior_pool: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_words: list[str] = []
            for lesson in unit.get("lessons", []):
                for word_id in lesson.get("wordIds", []):
                    if word_id not in unit_words:
                        unit_words.append(word_id)
            pool = set(_distractor_pool(unit_words, prior_pool))
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for step in lesson.get("steps", []):
                    kind = step.get("kind")
                    if kind not in {"watchChoose", "translationChoose"}:
                        continue
                    answer = step.get("answerWordId")
                    if not answer:
                        continue
                    distractors = set(step.get("distractorWordIds", []))
                    peers = semantic_distractor_peer_ids(answer) & pool
                    peers.discard(answer)
                    if peers and not peers & distractors:
                        warnings.append(
                            f"{lesson_id}: {kind} for {answer} has category peers "
                            f"in pool but none in distractorWordIds"
                        )
            for word_id in unit_words:
                if word_id not in prior_pool:
                    prior_pool.append(word_id)
    return warnings


def _phrase_cluster_teach(last_word: str | None, word: str | None) -> bool:
    if not last_word or not word:
        return False
    for phrase_id, comps in PHRASE_COMPONENTS.items():
        cluster = set(comps) | {phrase_id}
        if last_word in cluster and word in cluster:
            return True
    return False


def validate_intro_before_quiz(
    data: dict,
    introduced_at_path_start: set[str] | None = None,
) -> list[str]:
    """Hard errors: graded answers must follow a new-sign intro (watchChoose)."""
    errors: list[str] = []
    introduced: set[str] = set(introduced_at_path_start or set())
    quiz_kinds = frozenset({
        "watchChoose",
        "translationChoose",
        "wordPickVideo",
        "fillSlot",
        "fillGap",
        "meaningPick",
        "watchPick2",
        "watchPick4",
        "watchThenPick",
    })

    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                is_review = lesson_id.endswith("-review")
                sort_order = int(lesson.get("sortOrder") or 0)
                lesson_words = set(lesson.get("wordIds") or unit.get("words", []))
                lesson_introduced = set(introduced)
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind in {"signSequence", "phraseSlot"}:
                        for wid in step.get("sequenceWordIds", []):
                            if wid:
                                lesson_introduced.add(wid)
                        phrase = step.get("wordId")
                        if phrase:
                            lesson_introduced.add(phrase)
                        slot_answer = step.get("answerWordId")
                        if slot_answer and kind == "phraseSlot":
                            lesson_introduced.add(slot_answer)
                    answer = step.get("answerWordId")
                    is_new_intro = _is_new_sign_intro_step(
                        step, lesson_introduced, lesson_words
                    )
                    if answer and kind in quiz_kinds:
                        if answer not in lesson_introduced:
                            if kind == "watchChoose":
                                pass
                            elif answer in introduced:
                                pass
                            elif (
                                kind == "wordPickVideo"
                                and answer not in lesson_words
                                and sort_order == 4
                            ):
                                pass
                            elif kind == "wordPickVideo" and index > 0:
                                prev = lesson.get("steps", [])[index - 1]
                                if (
                                    prev.get("kind") == "watchChoose"
                                    and prev.get("answerWordId") == answer
                                ):
                                    pass
                                else:
                                    errors.append(
                                        f"{lesson_id} step {index}: {kind} for {answer} "
                                        f"before new-sign introduction"
                                    )
                            else:
                                errors.append(
                                    f"{lesson_id} step {index}: {kind} for {answer} "
                                    f"before new-sign introduction"
                                )
                    if is_new_intro or (answer and kind in quiz_kinds):
                        if answer:
                            lesson_introduced.add(answer)
                    if kind == "matchPairs":
                        for wid in step.get("pairWordIds", []):
                            if wid and wid not in lesson_introduced:
                                errors.append(
                                    f"{lesson_id} step {index}: matchPairs pair "
                                    f"{wid} before new-sign introduction"
                                )
                            if wid:
                                lesson_introduced.add(wid)
                    if kind == "speedBurst":
                        for wid in step.get("questionWordIds", []):
                            if wid and wid not in lesson_introduced:
                                errors.append(
                                    f"{lesson_id} step {index}: speedBurst question "
                                    f"{wid} before new-sign introduction"
                                )
                            if wid:
                                lesson_introduced.add(wid)
                introduced.update(lesson_introduced)
    return errors


_RUNTIME_INTRO_KINDS = frozenset({
    "watchChoose",
    "translationChoose",
    "wordPickVideo",
    "watchPick2",
    "watchPick4",
    "watchThenPick",
    "meaningPick",
})


def _is_new_sign_intro_step(
    step: dict,
    introduced: set[str],
    lesson_words: set[str],
) -> bool:
    kind = step.get("kind")
    if kind not in _RUNTIME_INTRO_KINDS:
        return False
    word = step.get("answerWordId")
    if not word or word not in lesson_words or word in PHRASE_IDS:
        return False
    return word not in introduced


def _track_step_intro(introduced: set[str], step: dict) -> None:
    answer = step.get("answerWordId")
    if answer:
        introduced.add(answer)
    if step.get("kind") in {"signSequence", "phraseSlot"}:
        phrase = step.get("wordId")
        if phrase:
            introduced.add(phrase)
        for wid in step.get("sequenceWordIds", []):
            if wid:
                introduced.add(wid)
    for wid in step.get("pairWordIds", []):
        if wid:
            introduced.add(wid)


MAX_BACK_TO_BACK_NEW_INTROS = 1
MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS = 1
MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS_STONE1 = 1
INTRO_CONFIRM_KINDS = frozenset({"watchChoose", "translationChoose", "wordPickVideo"})


def _is_teach_confirm_pair(prev: dict, step: dict) -> bool:
    if prev.get("kind") != "teach":
        return False
    word = prev.get("wordId")
    return (
        bool(word)
        and step.get("kind") in INTRO_CONFIRM_KINDS
        and step.get("answerWordId") == word
    )


def _max_teach_confirm_pairs_for_lesson(lesson_id: str) -> int:
    if lesson_id.endswith("-l1"):
        return MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS_STONE1
    return MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS


def validate_teach_confirm_streaks(data: dict) -> list[str]:
    """Hard errors: too many teach→intro-confirm pairs in a row (stone 1: max 1)."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                if lesson_id.endswith("-review"):
                    continue
                max_pairs = _max_teach_confirm_pairs_for_lesson(lesson_id)
                steps = lesson.get("steps", [])
                streak = 0
                index = 0
                while index < len(steps) - 1:
                    if _is_teach_confirm_pair(steps[index], steps[index + 1]):
                        streak += 1
                        if streak > max_pairs:
                            word = steps[index].get("wordId")
                            errors.append(
                                f"{lesson_id}: teach→confirm streak {streak} for {word!r} "
                                f"(max {max_pairs})"
                            )
                        index += 2
                    else:
                        streak = 0
                        index += 1
    return errors


def validate_no_adjacent_new_intros(data: dict) -> list[str]:
    """Hard errors: back-to-back new-sign introduction steps."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        introduced: set[str] = set()
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                if lesson_id.endswith("-review"):
                    continue
                lesson_words = set(lesson.get("wordIds") or unit.get("words", []))
                lesson_introduced = set(introduced)
                intro_streak = 0
                for index, step in enumerate(lesson.get("steps", [])):
                    is_new_intro = _is_new_sign_intro_step(
                        step, lesson_introduced, lesson_words
                    )
                    if is_new_intro:
                        intro_streak += 1
                        if intro_streak > MAX_BACK_TO_BACK_NEW_INTROS:
                            word = step.get("answerWordId")
                            prev_word = lesson.get("steps", [])[index - 1].get(
                                "answerWordId"
                            )
                            errors.append(
                                f"{lesson_id} step {index}: new sign {word} "
                                f"immediately after new sign {prev_word}"
                            )
                    else:
                        intro_streak = 0
                    _track_step_intro(lesson_introduced, step)
                introduced.update(lesson_introduced)
    return errors


def validate_stone1_answer_scope(data: dict) -> list[str]:
    """Stone 1 quizzes should use stone vocabulary plus up to two path-review words."""
    errors: list[str] = []
    quiz_kinds = frozenset({
        "watchChoose",
        "translationChoose",
        "wordPickVideo",
        "fillSlot",
        "fillGap",
        "meaningPick",
        "watchPick2",
        "watchPick4",
        "watchThenPick",
    })
    for path_doc in data.get("paths", []):
        prior_pool: list[str] = []
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            unit_sort_order = int(unit.get("sortOrder") or 0)
            subsets = UNIT_STONE_WORD_SUBSETS.get(unit_id, [])
            stone1_subset = subsets[0] if subsets else []
            for lesson in unit.get("lessons", []):
                if lesson.get("sortOrder") != 1:
                    continue
                lesson_id = lesson.get("id", "?")
                if lesson_id.endswith("-review"):
                    continue
                stone_words = set(lesson.get("wordIds") or [])
                allowlist = set(
                    stone1_review_candidates(
                        unit_sort_order,
                        prior_pool,
                        stone1_subset,
                    )
                )
                allowed = stone_words | allowlist
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    answer = step.get("answerWordId")
                    if answer and kind in quiz_kinds and answer not in allowed:
                        errors.append(
                            f"{lesson_id} step {index}: {kind} answer {answer} "
                            f"outside stone-1 vocabulary"
                        )
            for word_id in unit.get("words") or []:
                if word_id not in prior_pool:
                    prior_pool.append(word_id)
    return errors


def validate_lesson_rhythm(
    lesson_id: str,
    steps: list[dict],
    sort_order: int,
    introduced_at_lesson_start: set[str] | None = None,
    non_phrase_word_count: int | None = None,
) -> list[str]:
    errors: list[str] = []
    if not steps:
        return errors

    # Universal Unit Framework removed the timed speedBurst finale entirely.
    speed_bursts = [step for step in steps if step.get("kind") == "speedBurst"]
    if speed_bursts:
        errors.append(
            f"{lesson_id}: speedBurst is removed in the Universal Unit Framework, "
            f"found {len(speed_bursts)}"
        )

    # NOTE: consecutive-quiz and same-kind pacing are now handled by (a) runtime
    # teach injection in ModuleLessonView.buildPlaySteps (a "New Sign" screen is
    # inserted before each word's first recognition, breaking long quiz runs the
    # generator can't see) and (b) the dedicated variety rules in
    # validate_variety. So this rhythm pass only enforces hard structural issues.
    last_kind: str | None = None
    last_teach_word: str | None = None
    graded_streak = 0
    same_kind_streak = 0

    for index, step in enumerate(steps):
        kind = step.get("kind")
        if kind == "teach":
            if last_kind == "teach":
                wid = step.get("wordId")
                if not _phrase_cluster_teach(last_teach_word, wid):
                    errors.append(f"{lesson_id}: adjacent teach")
            last_teach_word = step.get("wordId")
            graded_streak = 0
            same_kind_streak = 0
        elif kind in QUIZ_KINDS:
            graded_streak += 1
            if kind == last_kind:
                same_kind_streak += 1
            else:
                same_kind_streak = 1
        elif kind in SHAPE_BREAK_KINDS:
            graded_streak = 0
            same_kind_streak = 0
        else:
            graded_streak = 0
            same_kind_streak = 0

        if kind == "teach":
            teach_word = step.get("wordId")
            if teach_word:
                follow = steps[index + 1 : index + 3]
                confirmed = any(
                    follow_step.get("answerWordId") == teach_word
                    or follow_step.get("wordId") == teach_word
                    for follow_step in follow
                )
                is_phrase_component = any(
                    teach_word in comps and teach_word != phrase_id
                    for phrase_id, comps in PHRASE_COMPONENTS.items()
                )
                if (
                    not confirmed
                    and not is_phrase_component
                    and teach_word not in PHRASE_COMPONENTS
                ):
                    errors.append(
                        f"{lesson_id}: teach for {teach_word} missing easy confirm within 2 steps"
                    )

        last_kind = kind

    prior_answer_ids: set[str] = set(introduced_at_lesson_start or set())
    for index, step in enumerate(steps):
        kind = step.get("kind")
        answer = step.get("answerWordId")
        if answer and kind not in {"teach", "selfSign"}:
            prior_answer_ids.add(answer)
        word_id = step.get("wordId")
        if word_id and kind not in {"teach", "selfSign"}:
            prior_answer_ids.add(word_id)

    return errors


def _accumulate_introduced(introduced: set[str], step: dict) -> None:
    kind = step.get("kind")
    if kind == "teach":
        if wid := step.get("wordId"):
            introduced.add(wid)
        return
    if kind in {"signSequence", "phraseSlot"}:
        for wid in step.get("sequenceWordIds", []):
            if wid:
                introduced.add(wid)
        if phrase := step.get("wordId"):
            introduced.add(phrase)
        return
    if kind == "matchPairs":
        for wid in step.get("pairWordIds", []):
            if wid:
                introduced.add(wid)
        return
    answer = step.get("answerWordId")
    word_id = step.get("wordId")
    if answer and kind not in {"selfSign", "teach"}:
        introduced.add(answer)
    if word_id and kind not in {"selfSign", "teach"}:
        introduced.add(word_id)


def validate_phrase_slot_steps(data: dict) -> list[str]:
    """Hard errors for phraseSlot pedagogy and schema."""
    errors: list[str] = []
    introduced: set[str] = set()
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind == "phraseSlot":
                        phrase = step.get("wordId")
                        slot_index = step.get("slotIndex")
                        answer = step.get("answerWordId")
                        sequence = step.get("sequenceWordIds", [])
                        distractors = step.get("distractorWordIds", [])

                        if not phrase or phrase not in PHRASE_COMPONENTS:
                            errors.append(
                                f"{lesson_id} step {index}: phraseSlot missing phrase wordId"
                            )
                        else:
                            components = PHRASE_COMPONENTS[phrase]
                            if sequence != components:
                                errors.append(
                                    f"{lesson_id} step {index}: phraseSlot sequence "
                                    f"mismatch for {phrase}"
                                )

                            if slot_index is None or not isinstance(slot_index, int):
                                errors.append(
                                    f"{lesson_id} step {index}: phraseSlot missing slotIndex"
                                )
                            elif slot_index < 0 or slot_index >= len(components):
                                errors.append(
                                    f"{lesson_id} step {index}: phraseSlot slotIndex out of range"
                                )
                            elif answer != components[slot_index]:
                                errors.append(
                                    f"{lesson_id} step {index}: phraseSlot answer {answer} "
                                    f"!= component at slot {slot_index}"
                                )

                            if answer in PHRASE_IDS:
                                errors.append(
                                    f"{lesson_id} step {index}: phraseSlot answer must be a component"
                                )

                            prefilled = {
                                components[i]
                                for i in range(len(components))
                                if i != slot_index
                            }
                            for distractor in distractors:
                                if distractor in PHRASE_IDS:
                                    errors.append(
                                        f"{lesson_id} step {index}: phraseSlot distractor "
                                        f"{distractor} must not be a phrase id"
                                    )
                                elif distractor == answer:
                                    errors.append(
                                        f"{lesson_id} step {index}: phraseSlot distractor "
                                        f"{distractor} must not be the answer"
                                    )
                                elif distractor in prefilled:
                                    errors.append(
                                        f"{lesson_id} step {index}: phraseSlot distractor "
                                        f"{distractor} is already shown in the phrase strip"
                                    )
                                elif distractor in components:
                                    errors.append(
                                        f"{lesson_id} step {index}: phraseSlot distractor "
                                        f"{distractor} must not be a phrase component"
                                    )

                            for component in {answer, *distractors}:
                                if component and component not in introduced:
                                    errors.append(
                                        f"{lesson_id} step {index}: phraseSlot component "
                                        f"{component} not introduced before step"
                                    )

                    _accumulate_introduced(introduced, step)
    return errors


def _sign_sequence_components(phrase_id: str) -> list[str]:
    raw = PHRASE_COMPONENTS.get(phrase_id, [])
    without_target = [c for c in raw if c != phrase_id]
    atomic = [c for c in without_target if c not in PHRASE_IDS]
    if len(atomic) >= 2:
        return atomic
    if len(without_target) >= 2:
        return without_target
    return list(raw)


def validate_sign_sequence_steps(data: dict) -> list[str]:
    """Hard errors when signSequence tiles are phrases instead of atomic signs."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "signSequence":
                        continue
                    phrase = step.get("wordId")
                    sequence = step.get("sequenceWordIds", [])
                    distractors = step.get("distractorWordIds", [])
                    expected = _sign_sequence_components(phrase) if phrase else []

                    if sequence != expected:
                        errors.append(
                            f"{lesson_id} step {index}: signSequence sequence "
                            f"mismatch for {phrase}"
                        )
                    if phrase and phrase in sequence and phrase not in expected:
                        errors.append(
                            f"{lesson_id} step {index}: signSequence must not "
                            f"include full phrase tile {phrase}"
                        )
                    if distractors:
                        errors.append(
                            f"{lesson_id} step {index}: signSequence must not "
                            f"include distractors (found {distractors})"
                        )
                    playable = [
                        word
                        for word in sequence
                        if word != phrase
                        or any(other != phrase for other in sequence)
                    ]
                    if len(playable) < 2:
                        errors.append(
                            f"{lesson_id} step {index}: signSequence for {phrase} "
                            f"needs at least 2 playable tiles (got {playable})"
                        )
    return errors


_PATH_INTRO_PROMPTS = frozenset({
    "New sign!",
    "First time seeing this",
    "Learn a new phrase!",
    "Watch this phrase!",
    "Here's a new phrase!",
    "See the whole sign!",
})


def validate_phrase_answer_distractors(data: dict) -> list[str]:
    """Hard errors: phrase answers must only list phrase ids as distractors."""
    errors: list[str] = []
    pick_kinds = frozenset({
        "watchChoose",
        "translationChoose",
        "wordPickVideo",
        "watchPick2",
        "watchPick4",
        "watchThenPick",
        "meaningPick",
        "fillSlot",
        "fillGap",
    })
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind not in pick_kinds:
                        continue
                    answer = step.get("answerWordId")
                    if not answer or answer not in PHRASE_IDS:
                        continue
                    for distractor in step.get("distractorWordIds", []):
                        if distractor not in PHRASE_IDS:
                            errors.append(
                                f"{lesson_id} step {index}: {kind} phrase answer "
                                f"{answer} has non-phrase distractor {distractor}"
                            )
    return errors


def validate_unique_teach_per_lesson(data: dict) -> list[str]:
    """Hard errors: at most one explicit teach step per word per lesson."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                seen: set[str] = set()
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "teach":
                        continue
                    word = step.get("wordId")
                    if not word:
                        continue
                    if word in seen:
                        errors.append(
                            f"{lesson_id} step {index}: duplicate teach for {word}"
                        )
                    else:
                        seen.add(word)
    return errors


def validate_unique_new_sign_introductions(data: dict) -> list[str]:
    """Hard errors: each word gets at most one new-sign / new-phrase intro on the path."""
    errors: list[str] = []
    seen: set[str] = set()
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    word = step.get("answerWordId")
                    prompt = step.get("prompt", "")
                    if kind not in {"watchChoose", "translationChoose", "wordPickVideo"}:
                        continue
                    if not word or prompt not in _PATH_INTRO_PROMPTS:
                        continue
                    if word in seen:
                        errors.append(
                            f"{lesson_id} step {index}: duplicate new-sign intro for {word}"
                        )
                    else:
                        seen.add(word)
    return errors


def _phrase_video_exercise_id(step: dict) -> str | None:
    kind = step.get("kind")
    if kind in _PHRASE_VIDEO_KINDS:
        return step.get("wordId")
    if kind == "fillSlot":
        word_id = step.get("wordId")
        if word_id in PHRASE_IDS:
            return word_id
    return None


def validate_one_phrase_video_exercise_per_lesson(data: dict) -> list[str]:
    """Hard errors: at most one signSequence or phraseSlot per phrase per lesson."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                seen_phrase: set[str] = set()
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind not in _PHRASE_VIDEO_KINDS:
                        continue
                    phrase_id = step.get("wordId")
                    if not phrase_id:
                        continue
                    if phrase_id in seen_phrase:
                        errors.append(
                            f"{lesson_id} step {index}: duplicate phrase-video "
                            f"exercise for {phrase_id}"
                        )
                    else:
                        seen_phrase.add(phrase_id)
    return errors


def validate_no_adjacent_match_pairs(data: dict) -> list[str]:
    """Hard errors: never stack two matchPairs exercises in a row."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                for index in range(len(steps) - 1):
                    if (
                        steps[index].get("kind") == "matchPairs"
                        and steps[index + 1].get("kind") == "matchPairs"
                    ):
                        errors.append(
                            f"{lesson_id} steps {index}-{index + 1}: adjacent matchPairs"
                        )
    return errors


def validate_no_adjacent_same_phrase_video(data: dict) -> list[str]:
    """Hard errors: never replay the same phrase clip on consecutive steps."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                for index in range(len(steps) - 1):
                    prev_id = _phrase_video_exercise_id(steps[index])
                    next_id = _phrase_video_exercise_id(steps[index + 1])
                    if prev_id and next_id and prev_id == next_id:
                        errors.append(
                            f"{lesson_id} steps {index}-{index + 1}: adjacent same "
                            f"phrase video ({prev_id})"
                        )
    return errors


def validate_no_phrase_fill_slot(data: dict) -> list[str]:
    """Hard errors: fillSlot must never use a full phrase id as the answer."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "fillSlot":
                        continue
                    answer = step.get("answerWordId")
                    if answer in PHRASE_IDS:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot answer {answer} "
                            f"must not be a phrase id"
                        )
    return errors


def _fill_slot_answer_label(answer: str) -> str:
    if answer in DISPLAY_OVERRIDES:
        return DISPLAY_OVERRIDES[answer].lower()
    return answer.replace("_", " ").replace("-", " ").lower()


def validate_fill_slot_sentences(data: dict) -> list[str]:
    """Hard errors: fillSlot must be phrase-backed with coherent sentence fragments."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "fillSlot":
                        continue
                    phrase_id = step.get("wordId")
                    answer = step.get("answerWordId")
                    before = step.get("sentenceBefore") or ""
                    after = step.get("sentenceAfter") or ""

                    if not phrase_id or phrase_id not in PHRASE_IDS:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot missing phrase wordId"
                        )
                        continue
                    if not answer:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot missing answerWordId"
                        )
                        continue
                    components = PHRASE_COMPONENTS.get(phrase_id, [])
                    if answer not in components:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot answer {answer} "
                            f"not a component of phrase {phrase_id}"
                        )
                    label = _fill_slot_answer_label(answer)
                    if after == f" — {label}." or after == f" — {answer.lower()}.":
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot uses legacy default "
                            f"sentenceAfter for {answer}"
                        )
                    if (
                        not before.strip()
                        and label in after.lower()
                        and answer.lower() in after.lower()
                    ):
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot sentenceAfter repeats "
                            f"answer {answer}"
                        )
                    for distractor in step.get("distractorWordIds", []):
                        if distractor == answer:
                            errors.append(
                                f"{lesson_id} step {index}: fillSlot distractor "
                                f"{distractor} must not equal answer"
                            )
                        elif distractor not in components:
                            errors.append(
                                f"{lesson_id} step {index}: fillSlot distractor "
                                f"{distractor} not in phrase {phrase_id}"
                            )
    return errors


def validate_phrase_fill_slots(data: dict) -> list[str]:
    """Hard errors: phrase-backed fillSlot steps must reference valid components."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "fillSlot":
                        continue
                    phrase_id = step.get("wordId")
                    if not phrase_id or phrase_id not in PHRASE_IDS:
                        continue
                    answer = step.get("answerWordId")
                    components = PHRASE_COMPONENTS.get(phrase_id, [])
                    if not answer:
                        errors.append(
                            f"{lesson_id} step {index}: phrase fillSlot missing answerWordId"
                        )
                        continue
                    if answer in PHRASE_IDS:
                        continue
                    if answer not in components:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot answer {answer} "
                            f"not a component of phrase {phrase_id}"
                        )
    return errors


PICK_CHOICE_KINDS = frozenset({
    "watchChoose",
    "translationChoose",
    "watchPick2",
    "watchPick4",
    "watchThenPick",
    "wordPickVideo",
    "meaningPick",
    "fillGap",
    "speedBurst",
})


def validate_pick_choice_counts(data: dict) -> list[str]:
    """Recognition steps must offer two or four choices — never an odd count."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                for index, step in enumerate(lesson.get("steps", [])):
                    kind = step.get("kind")
                    if kind not in PICK_CHOICE_KINDS:
                        continue
                    count = step.get("choiceCount")
                    if count is None:
                        continue
                    if count not in {2, 4}:
                        errors.append(
                            f"{lesson_id} step {index}: {kind} choiceCount={count} "
                            f"(must be 2 or 4)"
                        )
    return errors


def validate_fill_slot_choice_count(data: dict) -> list[str]:
    """fillSlot steps need at least two tile choices after phrase distractors are removed."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                pool = [
                    w
                    for w in lesson.get("wordIds", [])
                    if w not in PHRASE_IDS
                ]
                for index, step in enumerate(lesson.get("steps", [])):
                    if step.get("kind") != "fillSlot":
                        continue
                    answer = step.get("answerWordId")
                    if not answer or answer in PHRASE_IDS:
                        continue
                    distractors = [
                        w
                        for w in step.get("distractorWordIds", [])
                        if w != answer and w not in PHRASE_IDS
                    ]
                    choices = list(dict.fromkeys(distractors + [answer]))
                    if len(choices) < 2:
                        extras = [w for w in pool if w != answer and w not in distractors]
                        choices = list(dict.fromkeys(distractors + extras + [answer]))
                    if len(choices) < 2:
                        errors.append(
                            f"{lesson_id} step {index}: fillSlot answer {answer} "
                            f"has fewer than two single-word choices"
                        )
    return errors


def validate_phrase_sign_sequences(data: dict) -> list[str]:
    """Warn when a phrase-heavy unit lists phrases but has no signSequence step for them."""
    warnings: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            if unit_id not in PHRASE_SEQUENCE_UNITS:
                continue
            unit_phrases = [w for w in unit.get("words", []) if w in PHRASE_IDS]
            if not unit_phrases:
                for lesson in unit.get("lessons", []):
                    for word_id in lesson.get("wordIds", []):
                        if word_id in PHRASE_IDS and word_id not in unit_phrases:
                            unit_phrases.append(word_id)
            if not unit_phrases:
                continue
            sequenced: set[str] = set()
            for lesson in unit.get("lessons", []):
                for step in lesson.get("steps", []):
                    if step.get("kind") == "signSequence":
                        phrase = step.get("wordId")
                        if phrase:
                            sequenced.add(phrase)
            missing = [
                p
                for p in unit_phrases
                if p not in sequenced
                and len(PHRASE_COMPONENTS.get(p, [])) >= 2
            ]
            if missing:
                warnings.append(
                    f"{unit_id}: phrases without signSequence: {', '.join(missing)}"
                )
    return warnings


def validate_stone_word_subsets() -> list[str]:
    """Every regular teaching unit should have three stone subset rows."""
    from curriculum_v5_data import MIN_SIGNS_PER_STONE

    errors: list[str] = []
    spec_ids = {spec[0] for spec in UNIT_SPECS}
    for unit_id in sorted(spec_ids):
        subsets = UNIT_STONE_WORD_SUBSETS.get(unit_id)
        if not subsets:
            errors.append(f"{unit_id}: missing stone word subsets")
            continue
        if len(subsets) != 3:
            errors.append(f"{unit_id}: expected 3 stone subsets, got {len(subsets)}")
            continue

        unit_words = next(words for uid, *_rest, words in UNIT_SPECS if uid == unit_id)
        minimum_stone1 = min_unique_answers_for_unit(len(unit_words))
        if len(subsets[0]) < minimum_stone1 and len(unit_words) >= MIN_SIGNS_PER_STONE * 3:
            errors.append(
                f"{unit_id} stone 1: {len(subsets[0])} words "
                f"(minimum {minimum_stone1})"
            )
        if len(unit_words) < MIN_SIGNS_PER_STONE * 3:
            continue
        prev: set[str] = set()
        for stone_idx, batch in enumerate(subsets, start=1):
            new_words = [w for w in batch if w not in prev]
            new_count = len(new_words)
            prev.update(batch)
            required_total = MIN_SIGNS_PER_STONE * stone_idx
            if len(unit_words) < required_total:
                continue
            if new_count > 0 and all(w in PHRASE_IDS for w in new_words):
                continue
            min_new = 9 if stone_idx == 1 else 6
            if new_count < min_new:
                errors.append(
                    f"{unit_id} stone {stone_idx}: {new_count} new signs "
                    f"(minimum {min_new}; unit has {len(unit_words)} words)"
                )
    return errors


GRADED_STEP_KINDS = frozenset(
    {
        "watchChoose",
        "translationChoose",
        "wordPickVideo",
        "fillSlot",
        "matchPairs",
        "signSequence",
        "phraseSlot",
    }
)
PASSIVE_STEP_KINDS = frozenset({"aslTip", "yourTurn", "teach", "selfSign"})


def validate_phrase_sequence_coverage(data: dict) -> list[str]:
    """Each phrase unit must emit signSequence on at least one module stone."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            if unit_id not in PHRASE_SEQUENCE_UNITS:
                continue
            has_sequence = any(
                step.get("kind") == "signSequence"
                for lesson in unit.get("lessons", [])
                if lesson.get("type") == "module"
                and int(lesson.get("sortOrder") or 0) in {1, 2, 3}
                for step in lesson.get("steps", [])
            )
            if not has_sequence:
                errors.append(
                    f"{unit_id}: phrase unit missing signSequence in stones 1-3"
                )
    return errors


def validate_stone_lesson_mix(data: dict) -> tuple[list[str], list[str]]:
    """Errors on repetition, forbidden kinds, and weak exercise variety."""
    errors: list[str] = []
    warnings: list[str] = []
    review_or_milestone = ("-review", "-milestone-")
    spec_words = {spec[0]: spec[-1] for spec in UNIT_SPECS}

    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            if any(marker in unit_id for marker in review_or_milestone):
                continue
            unit_has_fill = bool(PHRASE_FILL_SLOTS.get(unit_id))
            unit_has_phrases = unit_id in PHRASE_SEQUENCE_UNITS
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                sort_order = int(lesson.get("sortOrder") or 0)
                if sort_order not in {1, 2, 3}:
                    continue
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                if not steps:
                    continue

                if sort_order == 1:
                    your_turn_count = sum(
                        1 for step in steps if step.get("kind") == "yourTurn"
                    )
                    if your_turn_count != 1:
                        errors.append(
                            f"{lesson_id}: stone 1 must have exactly 1 yourTurn "
                            f"(has {your_turn_count})"
                        )

                mid_needed = STONE_MID_YOUR_TURN.get(sort_order, 0)
                if mid_needed:
                    mid_count = _midlesson_your_turn_count(steps)
                    if mid_count < mid_needed:
                        errors.append(
                            f"{lesson_id}: stone {sort_order} must have "
                            f"{mid_needed} mid-lesson yourTurn (has {mid_count})"
                        )

                answers = [
                    step.get("answerWordId")
                    for step in steps
                    if step.get("answerWordId")
                ]
                kinds = {step.get("kind") for step in steps if step.get("kind")}
                graded_kinds = kinds & GRADED_STEP_KINDS
                graded_steps = [
                    step for step in steps if step.get("kind") in GRADED_STEP_KINDS
                ]

                min_kinds = 4
                if len(graded_kinds) < min_kinds:
                    errors.append(
                        f"{lesson_id}: only {len(graded_kinds)} graded exercise kinds "
                        f"(minimum {min_kinds})"
                    )

                required_s1 = {"watchChoose", "wordPickVideo", "matchPairs"}
                if sort_order == 1:
                    missing = required_s1 - graded_kinds
                    if missing:
                        errors.append(
                            f"{lesson_id}: stone 1 missing graded kinds {sorted(missing)}"
                        )
                    translation_choose_count = sum(
                        1
                        for step in graded_steps
                        if step.get("kind") == "translationChoose"
                    )
                    if translation_choose_count < 3:
                        errors.append(
                            f"{lesson_id}: stone 1 has {translation_choose_count} "
                            f"translationChoose (minimum 3)"
                        )
                    meaning_pick_count = sum(
                        1
                        for step in graded_steps
                        if step.get("kind") == "translationChoose"
                        and step.get("prompt") == "Pick the meaning."
                    )
                    if meaning_pick_count < 2:
                        errors.append(
                            f"{lesson_id}: stone 1 has {meaning_pick_count} "
                            f"'Pick the meaning.' checks (minimum 2)"
                        )
                    fill_anchors = set(PHRASE_FILL_SLOTS.get(unit_id, {}))
                    taught_words = {
                        step.get("wordId")
                        for step in steps
                        if step.get("kind") == "teach" and step.get("wordId")
                    }
                    if (
                        fill_anchors & taught_words
                        and "fillSlot" not in graded_kinds
                    ):
                        errors.append(f"{lesson_id}: stone 1 missing fillSlot")
                    if graded_steps:
                        watch_count = sum(
                            1 for step in graded_steps if step.get("kind") == "watchChoose"
                        )
                        if watch_count / len(graded_steps) > 0.40:
                            errors.append(
                                f"{lesson_id}: stone 1 watchChoose share "
                                f"{watch_count}/{len(graded_steps)} (max 40%)"
                            )
                        sign_to_word = sum(
                            1
                            for step in graded_steps
                            if step.get("kind") in {"watchChoose", "translationChoose"}
                        )
                        if sign_to_word / len(graded_steps) > 0.55:
                            errors.append(
                                f"{lesson_id}: stone 1 sign-to-word share "
                                f"{sign_to_word}/{len(graded_steps)} (max 55%)"
                            )

                if graded_steps:
                    recognition_count = sum(
                        1
                        for step in graded_steps
                        if step.get("kind") in RECOGNITION_KINDS
                    )
                    recognition_share = recognition_count / len(graded_steps)
                    cap = STONE_RECOGNITION_SHARE_CAP.get(sort_order, 0.65)
                    if recognition_share > cap + 0.05:
                        warnings.append(
                            f"{lesson_id}: recognition share "
                            f"{recognition_share:.0%} exceeds target cap {cap:.0%}"
                        )

                if answers:
                    unique = len(set(answers))
                    ratio = unique / len(answers)
                    if ratio < 0.4:
                        warnings.append(
                            f"{lesson_id}: answer variety low "
                            f"({unique}/{len(steps)} unique answers)"
                        )
                    top = Counter(answers).most_common(1)[0]
                    repeat_cap = repetition_rule(sort_order, "max_answer_reps")
                    if top[1] > repeat_cap:
                        errors.append(
                            f"{lesson_id}: answer {top[0]!r} appears {top[1]}x "
                            f"(cap {repeat_cap})"
                        )
                    else:
                        max_allowed = max(repeat_cap, math.ceil(len(answers) / max(1, unique)))
                        if top[1] > max_allowed:
                            warnings.append(
                                f"{lesson_id}: answer {top[0]!r} appears {top[1]}x "
                                f"(cap {max_allowed})"
                            )
    return errors, warnings


def validate_stone3_no_teaches(data: dict) -> list[str]:
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                if int(lesson.get("sortOrder") or 0) != 3:
                    continue
                if any(step.get("kind") == "teach" for step in lesson.get("steps", [])):
                    errors.append(
                        f"{lesson.get('id', '?')}: stone 3 must not include teach steps"
                    )
    return errors


def validate_one_recognition_modality_per_word(data: dict) -> list[str]:
    """Never use both watchChoose and wordPickVideo for the same answer in one lesson."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                lesson_id = lesson.get("id", "?")
                modalities: dict[str, set[str]] = {}
                for step in lesson.get("steps", []):
                    kind = step.get("kind")
                    if kind not in RECOGNITION_KINDS:
                        continue
                    answer = step.get("answerWordId")
                    if not answer:
                        continue
                    modalities.setdefault(answer, set()).add(kind)
                for word, kinds in modalities.items():
                    if "watchChoose" in kinds and "wordPickVideo" in kinds:
                        errors.append(
                            f"{lesson_id}: {word!r} uses both watchChoose and wordPickVideo"
                        )
    return errors


def validate_your_turn_budget(data: dict) -> list[str]:
    """Module units allow at most two yourTurn steps across all stones."""
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            if unit.get("isReview") or unit.get("isPhaseReview"):
                continue
            total = sum(
                1
                for lesson in unit.get("lessons", [])
                if lesson.get("type") == "module"
                for step in lesson.get("steps", [])
                if step.get("kind") == "yourTurn"
            )
            if total > 2:
                errors.append(
                    f"{unit.get('id', '?')}: {total} yourTurn steps (max 2 per unit)"
                )
    return errors


def validate_subset_teach_scope(data: dict) -> list[str]:
    errors: list[str] = []
    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            subsets = UNIT_STONE_WORD_SUBSETS.get(unit_id)
            if not subsets:
                continue
            for lesson in unit.get("lessons", []):
                if lesson.get("type") != "module":
                    continue
                stone = int(lesson.get("sortOrder") or 0)
                if stone not in {1, 2, 3}:
                    continue
                allowed: set[str] = set()
                for index in range(stone):
                    if index < len(subsets):
                        allowed.update(subsets[index])
                for step in lesson.get("steps", []):
                    if step.get("kind") != "teach":
                        continue
                    word = step.get("wordId")
                    if word and word not in allowed and word not in PHRASE_IDS:
                        errors.append(
                            f"{lesson.get('id', '?')}: teach {word!r} outside "
                            f"cumulative stone {stone} subset"
                        )
    return errors


def validate(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    taught: set[str] = set()
    introduced: set[str] = set()

    for path_doc in data.get("paths", []):
        for unit in path_doc.get("units", []):
            unit_id = unit.get("id", "?")
            for lesson in unit.get("lessons", []):
                lesson_id = lesson.get("id", "?")
                steps = lesson.get("steps", [])
                taught_at_lesson_start = set(taught)
                introduced_at_lesson_start = set(introduced)
                last_kind: str | None = None
                last_teach_word: str | None = None
                for step in steps:
                    kind = step.get("kind")
                    if kind == "teach":
                        wid = step.get("wordId")
                        if last_kind == "teach":
                            if not _phrase_cluster_teach(last_teach_word, wid):
                                errors.append(f"{lesson_id}: adjacent teach")
                        if wid and wid in taught and kind == "teach":
                            if wid not in PHRASE_IDS:
                                errors.append(f"{lesson_id}: refresher teach for {wid}")
                        if wid:
                            taught.add(wid)
                        last_teach_word = wid
                    elif kind in {"signSequence", "phraseSlot"}:
                        for wid in step.get("sequenceWordIds", []):
                            taught.add(wid)
                            introduced.add(wid)
                        phrase = step.get("wordId")
                        if phrase and phrase in PHRASE_COMPONENTS:
                            expected = _sign_sequence_components(phrase)
                            if step.get("sequenceWordIds") != expected:
                                errors.append(
                                    f"{lesson_id}: {kind} order mismatch for {phrase}"
                                )
                            taught.add(phrase)
                            introduced.add(phrase)
                    elif kind == "matchPairs":
                        if not lesson_id.endswith("-review"):
                            lesson_words = set(
                                lesson.get("wordIds") or unit.get("words", [])
                            )
                            for wid in step.get("pairWordIds", []):
                                if (
                                    wid not in introduced
                                    and wid not in taught
                                    and wid not in lesson_words
                                ):
                                    errors.append(
                                        f"{lesson_id}: untaught matchPairs id {wid}"
                                    )
                    elif kind == "speedBurst":
                        for wid in step.get("questionWordIds", []):
                            if wid not in taught:
                                errors.append(
                                    f"{lesson_id}: untaught speedBurst id {wid}"
                                )
                    else:
                        answer = step.get("answerWordId")
                        word_id = step.get("wordId")
                        if answer and kind not in {"selfSign", "teach"}:
                            taught.add(answer)
                            introduced.add(answer)
                        if word_id and kind not in {"selfSign", "teach"}:
                            taught.add(word_id)
                            introduced.add(word_id)
                    if kind == "memoryCountdown":
                        errors.append(f"{lesson_id}: deprecated memoryCountdown step")
                    last_kind = kind

                if (
                    lesson.get("type") == "module"
                    and lesson.get("sortOrder") in {1, 2, 3}
                    and not str(lesson_id).endswith("-review")
                ):
                    lesson_words = lesson.get("wordIds", [])
                    non_phrase_count = len(
                        [w for w in lesson_words if w not in PHRASE_COMPONENTS]
                    )
                    errors.extend(
                        validate_lesson_rhythm(
                            lesson_id,
                            steps,
                            int(lesson.get("sortOrder") or 0),
                            introduced_at_lesson_start,
                            non_phrase_count,
                        )
                    )
    return errors


def main() -> None:
    path = Path(__file__).parent / "curriculum.json"
    if len(sys.argv) > 1:
        path = Path(sys.argv[1])
    data = json.loads(path.read_text(encoding="utf-8"))
    errors = validate(path)
    errors.extend(validate_stone_word_subsets())
    errors.extend(validate_min_unique_answers_per_stone(data))
    errors.extend(validate_intro_before_quiz(data))
    errors.extend(validate_stone1_answer_scope(data))
    density_errors, density_warnings = validate_answer_density(data)
    errors.extend(density_errors)
    errors.extend(validate_no_adjacent_same_graded_answer(data))
    errors.extend(validate_no_adjacent_new_intros(data))
    errors.extend(validate_teach_confirm_streaks(data))
    errors.extend(validate_phrase_video_availability(data))
    errors.extend(validate_phrase_slot_steps(data))
    errors.extend(validate_sign_sequence_steps(data))
    errors.extend(validate_one_phrase_video_exercise_per_lesson(data))
    errors.extend(validate_no_adjacent_same_phrase_video(data))
    errors.extend(validate_no_adjacent_match_pairs(data))
    errors.extend(validate_no_phrase_fill_slot(data))
    errors.extend(validate_fill_slot_sentences(data))
    errors.extend(validate_phrase_fill_slots(data))
    errors.extend(validate_pick_choice_counts(data))
    errors.extend(validate_fill_slot_choice_count(data))
    errors.extend(validate_unique_teach_per_lesson(data))
    errors.extend(validate_unique_new_sign_introductions(data))
    errors.extend(validate_phrase_answer_distractors(data))
    video_warnings = validate_answer_video_availability(data)
    warnings = validate_semantic_distractors(data)
    phrase_warnings = validate_phrase_sign_sequences(data)
    variety_warnings = validate_variety(data)
    errors.extend(validate_stone3_no_teaches(data))
    errors.extend(validate_one_recognition_modality_per_word(data))
    errors.extend(validate_your_turn_budget(data))
    errors.extend(validate_subset_teach_scope(data))
    gap_errors = validate_min_answer_gap(data)
    errors.extend(gap_errors)
    asl_tip_warnings = validate_asl_tip_stone1(data)
    stone_mix_errors, stone_mix_warnings = validate_stone_lesson_mix(data)
    errors.extend(stone_mix_errors)
    errors.extend(validate_phrase_sequence_coverage(data))
    length_errors, length_warnings = validate_lengths(data)
    errors.extend(length_errors)
    if video_warnings:
        print(f"Video availability warnings ({len(video_warnings)}):")
        for warning in video_warnings[:30]:
            print(f"  - {warning}")
        if len(video_warnings) > 30:
            print(f"  ... and {len(video_warnings) - 30} more")
    if length_warnings:
        print(f"Length-target warnings ({len(length_warnings)}):")
        for warning in length_warnings[:20]:
            print(f"  - {warning}")
        if len(length_warnings) > 20:
            print(f"  ... and {len(length_warnings) - 20} more")
    if variety_warnings:
        print(f"Variety warnings ({len(variety_warnings)}):")
        for warning in variety_warnings[:20]:
            print(f"  - {warning}")
        if len(variety_warnings) > 20:
            print(f"  ... and {len(variety_warnings) - 20} more")
    if gap_errors:
        print(f"Answer-gap errors ({len(gap_errors)}):")
        for err in gap_errors[:20]:
            print(f"  - {err}")
        if len(gap_errors) > 20:
            print(f"  ... and {len(gap_errors) - 20} more")
    if asl_tip_warnings:
        print(f"aslTip warnings ({len(asl_tip_warnings)}):")
        for warning in asl_tip_warnings[:20]:
            print(f"  - {warning}")
        if len(asl_tip_warnings) > 20:
            print(f"  ... and {len(asl_tip_warnings) - 20} more")
    if stone_mix_warnings:
        print(f"Stone mix warnings ({len(stone_mix_warnings)}):")
        for warning in stone_mix_warnings[:30]:
            print(f"  - {warning}")
        if len(stone_mix_warnings) > 30:
            print(f"  ... and {len(stone_mix_warnings) - 30} more")
    if density_warnings:
        print(f"Answer density warnings ({len(density_warnings)}):")
        for warning in density_warnings[:20]:
            print(f"  - {warning}")
        if len(density_warnings) > 20:
            print(f"  ... and {len(density_warnings) - 20} more")
    if phrase_warnings:
        print(f"Phrase signSequence warnings ({len(phrase_warnings)}):")
        for warning in phrase_warnings[:20]:
            print(f"  - {warning}")
        if len(phrase_warnings) > 20:
            print(f"  ... and {len(phrase_warnings) - 20} more")
    if warnings:
        print(f"Semantic distractor warnings ({len(warnings)}):")
        for warning in warnings[:20]:
            print(f"  - {warning}")
        if len(warnings) > 20:
            print(f"  ... and {len(warnings) - 20} more")
    if errors:
        print(f"Found {len(errors)} issue(s):")
        for err in errors[:50]:
            print(f"  - {err}")
        if len(errors) > 50:
            print(f"  ... and {len(errors) - 50} more")
        sys.exit(1)
    print(f"OK: {path} passed pedagogy checks ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
