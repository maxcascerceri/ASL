#!/usr/bin/env python3
"""Generate ASL curriculum v6.0.0 (the 3-stone model) into curriculum.json.

Each unit has exactly three module lessons. The module engine consumes a list
of `steps` per lesson and the v4.0.0 schema supports the following step kinds:

  - `teach`        - show the sign + word label, no answer required
  - `watchPick2`   - 2-choice tap-the-word pick
  - `watchPick4`   - 4-choice tap-the-word pick
  - `wordPickVideo` - word prompt + two stacked video choices
  - `watchThenPick` - video first, then choices after a short beat
  - `watchChoose`  - video + choices, checked by the bottom button
  - `translationChoose` - translation check with bottom-button grading
  - `fillSlot`     - sentence blank where selected word fills the slot
  - `phraseSlot`   - phrase video with one missing component sign to pick
  - `matchPairs`   - match multiple sign videos with translations
  - `signSequence` - pick phrase components in canonical sign order
  - `fillGap`      - short sentence with the video acting as the blank

Each stone follows a 9-beat emotional arc (warm-up → teach → confirm → … →
speed burst) so lessons build toward celebration instead of quiz padding.

Run from the repo root:

    python3 scripts/generate_curriculum_v4.py

Writes to scripts/curriculum.json. Sentence content lives in `SENTENCES` below
so future edits are a one-file change.
"""

from __future__ import annotations

import csv
import json
import math
import zlib
from collections import Counter
from pathlib import Path

from curriculum_v5_data import (
    DISPLAY_OVERRIDES,
    PHASE_CHECKPOINT_BADGES,
    PHASE_SEGMENTS,
    PHRASE_COMPONENTS,
    PHRASE_FILL_PROMPT,
    PHRASE_CONTEXT_SIGN_SEQUENCES,
    PHRASE_FILL_SLOTS,
    PHRASE_IDS,
    PHRASE_SEQUENCE_UNITS,
    SENTENCE_OVERRIDES,
    UNIT_ORDER_BY_TITLE,
    UNIT_SPECS,
    UNIT_STONE_WORD_SUBSETS,
    cumulative_stone_words,
    min_unique_answers_for_unit,
    semantic_distractor_peer_ids,
    stone1_review_candidates,
    stone_display_title,
    stone_phrase_ids,
)

from asl_tips_catalog import alloc_asl_tip

VERSION = "6.0.0"

# Curriculum does not gate steps on filmed status — unfilmed signs and phrases
# stay in lessons and the app shows the coming-soon video placeholder at runtime.

CHECKPOINT_CONFIG = {
    "passRatio": 0.75,
    "lengthMultiplier": 2,
    "distribution": {
        "watchPick2": 0.3,
        "watchPick4": 0.4,
        "fillGap": 0.3,
    },
    "redrillType": "watchPick4",
    "redrillPassRatio": 1.0,
    "selfSignFinale": True,
}

# Units intentionally without fillGap content (raw alphabet letters). Stones 3
# and 4 for these units rely on watchPick2 / watchPick4 / teach refresher mixes
# instead. Every other unit must have an entry in `SENTENCES` below.
NO_FILLGAP_UNITS: set[str] = {
    "p1-u10", "p1-u11", "p1-u13",
}

MIN_MODULE_STEPS = 10
MAX_MODULE_STEPS = 12

# Universal Unit Framework per-stone length targets (graded screens; runtime
# adds teach + confirm and mistake review on top).
#   Stones 1–3         22-34 graded screens (+ teach confirm in runtime)
STONE_MIN_STEPS = {1: 24, 2: 26, 3: 22}
STONE_MIN_YOUR_TURN = {1: 1, 2: 1, 3: 0}
STONE_MID_YOUR_TURN = {1: 1, 2: 1, 3: 0}
STONE_MIN_TRANSLATION_CHOOSE = {1: 3, 2: 2, 3: 2}
STONE1_MIN_TRANSLATION_CHOOSE = STONE_MIN_TRANSLATION_CHOOSE[1]
STONE1_TRANSLATION_CHOOSE_PROMPT = "Pick the meaning."
STONE1_MIN_WORD_PICK_VIDEO = 2
STONE_MIN_MATCH_PAIRS = {1: 1, 2: 1, 3: 1}
STONE_MIN_CONTEXT_STEPS = {2: 2, 3: 3}
RECOGNITION_KINDS = frozenset({"watchChoose", "wordPickVideo"})
CONTEXT_STEP_KINDS = frozenset({"fillSlot", "signSequence", "phraseSlot"})
STONE_RECOGNITION_SHARE_CAP = {1: 0.68, 2: 0.62, 3: 0.55}
STONE_WATCH_TO_WORD_PICK_TARGET = {
    1: (0.60, 0.40),
    2: (0.50, 0.50),
    3: (0.45, 0.55),
}
STONE_MAX_STEPS = {1: 32, 2: 34, 3: 28}
MAX_BACK_TO_BACK_NEW_INTROS = 1
# Cap teach → intro-confirm pairs (e.g. teach then "What sign is this?") in a row.
MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS = 1
MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS_STONE1 = 1

# Phase checkpoint: a longer, phrase-heavy recap mix.
PHASE_REVIEW_STEPS = 14
CATEGORY_CHALLENGE_MIN_STEPS = 12
CATEGORY_CHALLENGE_MAX_STEPS = 18
MAX_PHRASE_OPENER = 4

# ----------------------------------------------------------------------------
# UNITS: source of truth for each unit's content. `words` is the canonical
# list of words taught in that unit; every Stone draws its question set from
# this list. Home-path order is defined in UNIT_ORDER_BY_TITLE (v5 data module).
# ----------------------------------------------------------------------------


def _build_units() -> list[dict]:
    units: list[dict] = []
    for uid, title, desc, badge, words in UNIT_SPECS:
        unit: dict = {
            "id": uid,
            "title": title,
            "description": desc,
            "badge": badge,
            "sortOrder": 0,
            "words": words,
        }
        units.append(unit)
    return units


UNITS: list[dict] = _build_units()


def _phase_for_index(index_1based: int) -> tuple[str, str]:
    for end, phase_key, phase_title in PHASE_SEGMENTS:
        if index_1based <= end:
            return phase_key, phase_title
    return PHASE_SEGMENTS[-1][1], PHASE_SEGMENTS[-1][2]


def ordered_units() -> list[dict]:
    by_title = {unit["title"]: unit for unit in UNITS}
    missing = [title for title in UNIT_ORDER_BY_TITLE if title not in by_title]
    if missing:
        raise ValueError(f"UNIT_ORDER_BY_TITLE references unknown units: {missing}")
    extra = sorted(set(by_title) - set(UNIT_ORDER_BY_TITLE))
    if extra:
        raise ValueError(f"UNITS not listed in UNIT_ORDER_BY_TITLE: {extra}")

    ordered: list[dict] = []
    for index, title in enumerate(UNIT_ORDER_BY_TITLE, start=1):
        unit = dict(by_title[title])
        phase_key, phase_title = _phase_for_index(index)
        unit["phaseKey"] = phase_key
        unit["phaseTitle"] = phase_title
        unit["sortOrder"] = index
        ordered.append(unit)
    return ordered


# ----------------------------------------------------------------------------
# SENTENCES: Fill-the-Gap content for each unit that uses Stone 3 = fillGap.
# Format: unit_id -> word -> (sentenceBefore, sentenceAfter)
# Constraint: sentenceBefore + answer + sentenceAfter is <= 5 words total so
# the rendered line never wraps on screen.
# ----------------------------------------------------------------------------

_LEGACY_SENTENCES: dict[str, dict[str, tuple[str, str]]] = {
    "p1-u01": {
        "hello": ("", ", my name Max."),
        "bye": ("", " for now!"),
        "please": ("Coffee, ", "."),
        "thankyou": ("", " so much!"),
        "sorry": ("", ", I dropped it."),
        "welcome": ("You're ", " here."),
        "congratulations": ("", " on winning!"),
        "oops": ("", ", my mistake!"),
    },
    "p1-u02": {
        "yes": ("", ", I agree."),
        "no": ("", ", not today."),
        "sure": ("", ", count me in."),
        "wow": ("", ", that's amazing!"),
        "really": ("", "? Tell me more."),
        "alright": ("", ", let's begin."),
        "ok": ("", ", sounds good."),
    },
    "p1-u03": {
        "i": ("", " love ASL."),
        "me": ("Wait for ", "!"),
        "you": ("", " are amazing!"),
        "we": ("", " can do it."),
        "us": ("Come with ", "."),
        "our": ("", " home is here."),
    },
    "p1-u04": {
        "my": ("That is ", " book."),
        "your": ("Is this ", " bag?"),
        "his": ("", " name is Sam."),
        "mine": ("That seat is ", "."),
        "he": ("", " loves coffee."),
        "they": ("", " arrived early today."),
    },
    "p1-u05": {
        "person": ("One ", " is here."),
        "people": ("Many ", " are coming."),
        "myself": ("", ", I love this."),
        "yourself": ("Tell me about ", "."),
        "name": ("What is your ", "?"),
        "sign": ("Show me your ", "."),
    },
    "p1-u06": {
        "happy": ("I feel ", " today."),
        "sad": ("She feels ", " now."),
        "good": ("That's a ", " idea."),
        "bad": ("That was ", "."),
        "fine": ("I am ", ", thanks."),
        "great": ("That looks ", "!"),
        "tired": ("I am very ", "."),
    },
    "p1-u07": {
        "what": ("", " is your plan?"),
        "where": ("", " are you going?"),
        "when": ("", " does it start?"),
        "who": ("", " told you that?"),
        "why": ("", " are you laughing?"),
        "how": ("", " did you do it?"),
        "which": ("", " one do you prefer?"),
    },
    "p1-u08": {
        "and": ("Tea ", " coffee, please."),
        "but": ("Small ", " strong."),
        "or": ("Coffee ", " tea?"),
        "so": ("It's late, ", " I'm leaving."),
        "with": ("Come ", " us today."),
        "without": ("Coffee ", " sugar, please."),
    },
    "p1-u09": {
        "very": ("She is ", " kind."),
        "really": ("", " loud music here."),
        "almost": ("", " time for dinner."),
        "many": ("", " books on shelves."),
        "few": ("Only a ", " left."),
        "enough": ("That is ", " for now."),
    },
    "p1-u14": {
        "alphabet": ("Sing the ", " song."),
        "fingerspell": ("I will ", " my name."),
        "letter": ("Pick a ", " card."),
        "language": ("ASL is my ", "."),
        "word": ("Spell that ", " out."),
    },
    "p1-u15": {
        "zero": ("Start at ", "."),
        "one": ("Just ", " more, please."),
        "two": ("I need ", " forks."),
        "three": ("Order ", " coffees."),
        "four": ("Pack ", " sandwiches."),
        "six": ("She has ", " puppies."),
        "seven": ("Wait ", " minutes."),
        "eight": ("There are ", " chairs."),
        "nine": ("Game ends at ", "."),
        "eleven": ("Train leaves at ", "."),
    },
    "p1-u16": {
        "half": ("Cut it in ", "."),
        "quarter": ("A ", " hour left."),
        "percent": ("Twenty ", " off!"),
        "double": ("Order a ", " burger."),
        "triple": ("That's a ", " win!"),
        "hundred": ("One ", " people came."),
    },
    "p1-u17": {
        "money": ("Save your ", " carefully."),
        "pay": ("I will ", " now."),
        "cost": ("What does it ", "?"),
        "price": ("Check the ", " tag."),
        "1dollar": ("Just ", " left."),
        "5dollars": ("That's ", " total."),
    },
    "p1-u18": {
        "mother": ("My ", " loves us."),
        "father": ("My ", " works hard."),
        "sister": ("My ", " plays piano."),
        "brother": ("My ", " loves sports."),
        "baby": ("The ", " is asleep."),
        "child": ("Every ", " loves play."),
        "family": ("Our ", " is small."),
        "parents": ("My ", " came over."),
    },
    "p1-u19": {
        "grandmother": ("My ", " bakes pies."),
        "grandfather": ("My ", " loves stories."),
        "aunt": ("My ", " visits us."),
        "uncle": ("My ", " fishes weekly."),
        "cousin": ("My ", " moved away."),
        "niece": ("My ", " is shy."),
        "nephew": ("My ", " loves cars."),
        "twins": ("Those ", " look alike."),
    },
    "p1-u20": {
        "man": ("That ", " is tall."),
        "woman": ("That ", " is kind."),
        "boy": ("The ", " kicked it."),
        "girl": ("The ", " is reading."),
        "adult": ("An ", " ticket, please."),
        "teenager": ("That ", " is quick."),
    },
    "p1-u22": {
        "interpreter": ("The ", " arrived early."),
        "caption": ("Read the ", " below."),
        "hearingaid": ("He uses a ", "."),
        "lipread": ("I can ", " sometimes."),
        "gesture": ("Make a ", " back."),
        "translate": ("Please ", " this sign."),
    },
    "p1-u23": {
        "go": ("Let's ", " home now."),
        "come": ("", " with us!"),
        "walk": ("I ", " every morning."),
        "run": ("We ", " at the park."),
        "stop": ("Please ", " for me."),
        "turn": ("", " left here."),
        "move": ("", " over please."),
    },
    "p1-u24": {
        "eat": ("We ", " at six."),
        "drink": ("", " more water today."),
        "sleep": ("I ", " eight hours."),
        "see": ("I ", " a bird."),
        "hear": ("Can you ", " that?"),
        "feel": ("I ", " happy today."),
        "hurt": ("Did that ", " you?"),
        "breathe": ("Slowly ", " in, out."),
    },
    "p1-u25": {
        "tell": ("Please ", " me later."),
        "ask": ("Can I ", " something?"),
        "talk": ("Let's ", " tomorrow."),
        "think": ("I ", " so too."),
        "know": ("I ", " your name."),
        "understand": ("I ", " now."),
        "believe": ("I ", " you completely."),
        "learn": ("We ", " every day."),
    },
    "p1-u26": {
        "make": ("I'll ", " us lunch."),
        "get": ("Please ", " the door."),
        "give": ("", " it to me."),
        "take": ("Please ", " this away."),
        "use": ("I ", " this often."),
        "find": ("Can you ", " it?"),
        "want": ("I ", " coffee, please."),
        "help": ("Can you ", " me?"),
    },
    "p1-u27": {
        "red": ("The apple is ", "."),
        "blue": ("The sky looks ", "."),
        "green": ("Grass is always ", "."),
        "yellow": ("Bananas are usually ", "."),
        "orange": ("An orange is ", "."),
        "purple": ("Grapes look ", "."),
        "pink": ("Roses can be ", "."),
        "brown": ("Bears are often ", "."),
    },
    "p1-u28": {
        "black": ("My cat is ", "."),
        "white": ("Snow is bright ", "."),
        "gray": ("Clouds turned ", " today."),
        "gold": ("The ring looked ", "."),
        "silver": ("Her hair is ", "."),
        "dark": ("It is ", " outside."),
        "light": ("Turn the ", " on."),
        "bright": ("This room is ", "."),
    },
    "p1-u29": {
        "big": ("What a ", " surprise!"),
        "small": ("A ", " coffee, please."),
        "tall": ("He is very ", "."),
        "hot": ("The soup is ", "."),
        "cold": ("My hands are ", "."),
        "fast": ("He runs ", "."),
        "slow": ("Drive ", " here."),
        "hard": ("This test is ", "."),
    },
    "p1-u30": {
        "home": ("I'm going ", " now."),
        "house": ("Our ", " is blue."),
        "kitchen": ("She cooks in the ", "."),
        "bathroom": ("The ", " is upstairs."),
        "bedroom": ("My ", " is tidy."),
        "livingroom": ("The ", " has couches."),
        "basement": ("Our ", " is cold."),
        "backyard": ("Dogs play in the ", "."),
    },
    "p1-u31": {
        "table": ("Set the ", " for dinner."),
        "chair": ("Sit on the ", "."),
        "bed": ("I made my ", "."),
        "couch": ("He naps on the ", "."),
        "door": ("Please close the ", "."),
        "window": ("Open the ", " wide."),
        "lamp": ("Turn on the ", "."),
        "clock": ("Check the ", " quickly."),
    },
    "p1-u32": {
        "shower": ("I take a ", " daily."),
        "toilet": ("The ", " is here."),
        "sink": ("Wash hands in the ", "."),
        "soap": ("Use plenty of ", "."),
        "toothbrush": ("My ", " is new."),
        "brush": ("", " your hair now."),
        "comb": ("I lost my ", "."),
    },
    "p1-u33": {
        "clean": ("Please ", " your room."),
        "wash": ("", " the clothes today."),
        "cook": ("I love to ", "."),
        "sweep": ("Please ", " the floor."),
        "vacuum": ("Time to ", " here."),
        "washdishes": ("I'll ", " tonight."),
    },
    "p1-u34": {
        "breakfast": ("Eat ", " every morning."),
        "lunch": ("Let's get ", " soon."),
        "dinner": ("What's for ", " tonight?"),
        "hungry": ("I'm so ", "!"),
        "full": ("I'm completely ", "."),
        "delicious": ("This pasta is ", "."),
    },
    "p1-u35": {
        "apple": ("An ", " a day."),
        "banana": ("Peel the ", " carefully."),
        "orange": ("Squeeze an ", " for juice."),
        "grapes": ("", " grow on vines."),
        "strawberry": ("Eat one ", " slowly."),
        "cherry": ("", " pie tastes great."),
        "pineapple": ("", " is sweet today."),
        "lemon": ("Add some ", " juice."),
    },
    "p1-u36": {
        "tomato": ("Slice a ", " thin."),
        "carrot": ("Munch a ", " slowly."),
        "corn": ("Sweet ", " is yellow."),
        "onion": ("Chop the ", " first."),
        "potato": ("Bake the ", " whole."),
        "lettuce": ("Wash the ", " carefully."),
    },
    "p1-u37": {
        "meat": ("Cook the ", " well."),
        "fish": ("", " swim in water."),
        "egg": ("I eat one ", "."),
        "cheese": ("Slice the ", " thin."),
        "milk": ("Pour cold ", " here."),
        "butter": ("Spread ", " on bread."),
        "bacon": ("Crispy ", " for breakfast."),
    },
    "p1-u38": {
        "bread": ("Slice the fresh ", "."),
        "pizza": ("I love ", " nights."),
        "cake": ("Cut a ", " slice."),
        "chocolate": ("Dark ", " is best."),
        "water": ("Drink more ", " daily."),
        "coffee": ("I need strong ", "."),
        "tea": ("Hot ", " please."),
        "juice": ("Fresh orange ", ", please."),
    },
    "p1-u39": {
        "monday": ("See you on ", "."),
        "tuesday": ("Yoga every ", " morning."),
        "wednesday": ("Meeting on ", " noon."),
        "thursday": ("Late lunch ", "."),
        "friday": ("Movie night ", "."),
        "saturday": ("Sleep in ", " morning."),
        "sunday": ("Brunch every ", "."),
    },
    "p1-u40": {
        "morning": ("Good ", ", everyone!"),
        "afternoon": ("", " coffee is nice."),
        "night": ("", " falls quickly."),
        "today": ("", " is my birthday."),
        "yesterday": ("", " was fun."),
        "tomorrow": ("See you ", "!"),
        "now": ("We leave ", "."),
        "noon": ("Lunch at ", " sharp."),
    },
    "p1-u41": {
        "day": ("Have a great ", "."),
        "week": ("Next ", " is busy."),
        "month": ("Last ", " was hot."),
        "year": ("Happy new ", "!"),
        "hour": ("Wait one ", " please."),
        "minute": ("Give me a ", "."),
        "weekend": ("Long ", " ahead."),
        "holiday": ("Happy ", ", friend!"),
    },
    "p1-u42": {
        "head": ("I bumped my ", "."),
        "face": ("Wash your ", " gently."),
        "eyes": ("Her ", " are blue."),
        "ear": ("My right ", " itches."),
        "nose": ("Wipe your ", " quickly."),
        "mouth": ("Cover your ", ", please."),
        "teeth": ("Brush your ", " nightly."),
        "tongue": ("Stick out your ", "."),
    },
    "p1-u43": {
        "body": ("My whole ", " aches."),
        "arm": ("Lift your right ", "."),
        "hands": ("Wash your ", " first."),
        "finger": ("I cut my ", "."),
        "shoulder": ("My left ", " hurts."),
        "neck": ("My ", " is stiff."),
        "back": ("My ", " is sore."),
        "stomach": ("My ", " is full."),
    },
    "p1-u44": {
        "sick": ("I feel so ", " today."),
        "hurt": ("My ankle is ", "."),
        "pain": ("The ", " is sharp."),
        "headache": ("I have a ", "."),
        "cough": ("My ", " is worse."),
        "sneeze": ("I might ", " soon."),
        "tired": ("I'm so ", " today."),
        "dizzy": ("I feel a bit ", "."),
    },
    "p1-u45": {
        "health": ("Good ", " matters most."),
        "exercise": ("I ", " every morning."),
        "doctor": ("See the ", " soon."),
        "nurse": ("The ", " was kind."),
        "hospital": ("He's at the ", "."),
        "medicine": ("Take your ", " now."),
    },
    "p1-u46": {
        "happy": ("I feel so ", "!"),
        "sad": ("She seems quite ", "."),
        "angry": ("He looked very ", "."),
        "scared": ("I was ", " then."),
        "excited": ("I'm so ", " today!"),
        "worry": ("Try not to ", "."),
    },
    "p1-u47": {
        "bored": ("I'm so ", " today."),
        "lonely": ("She felt very ", "."),
        "jealous": ("Don't get ", "."),
        "embarrass": ("I might ", " myself."),
        "frustrate": ("Slow drivers ", " me."),
        "surprise": ("What a wonderful ", "!"),
    },
    "p1-u48": {
        "confident": ("She seems very ", "."),
        "humble": ("He stays ", " always."),
        "lazy": ("Don't be ", "."),
        "stubborn": ("He's quite ", "."),
        "curious": ("She looked ", "."),
        "serious": ("Are you being ", "?"),
    },
    "p1-u49": {
        "love": ("I ", " you, friend."),
        "like": ("I really ", " this."),
        "hate": ("I ", " loud noises."),
        "friend": ("My best ", " arrived."),
        "hug": ("Give me a ", "."),
        "kiss": ("A goodnight ", " always."),
    },
    "p1-u50": {
        "shirt": ("Iron the blue ", "."),
        "pants": ("These ", " feel tight."),
        "dress": ("She wore a ", "."),
        "shoes": ("Polish your ", " today."),
        "socks": ("Wear warm ", " tonight."),
        "jacket": ("Bring your ", " along."),
        "hat": ("I lost my ", "."),
        "clothes": ("Fold the clean ", "."),
    },
    "p1-u51": {
        "shorts": ("Wear cool ", " today."),
        "skirt": ("That ", " is pretty."),
        "sweater": ("Grab a warm ", "."),
        "boots": ("Snow ", " are warm."),
        "gloves": ("Wear thick ", " outside."),
        "scarf": ("Wrap a soft ", " on."),
        "belt": ("Adjust your ", " first."),
        "suit": ("Wear your nicest ", "."),
    },
    "p1-u52": {
        "glasses": ("Where are my ", "?"),
        "earring": ("I found one ", "."),
        "necklace": ("Her ", " sparkled."),
        "bracelet": ("My ", " broke today."),
        "ring": ("She wore a ", "."),
        "backpack": ("Pack your ", " tonight."),
        "wallet": ("I lost my ", "."),
    },
    "p1-u53": {
        "car": ("Park the ", " here."),
        "bus": ("Catch the next ", "."),
        "train": ("Ride the early ", "."),
        "airplane": ("Board the ", " soon."),
        "bike": ("My new ", " is fast."),
        "truck": ("Load the ", " carefully."),
        "motorcycle": ("His ", " is loud."),
        "boat": ("The ", " sails today."),
    },
    "p1-u54": {
        "here": ("Come ", " quickly!"),
        "there": ("Look over ", "!"),
        "left": ("Turn ", " at light."),
        "right": ("Stay to the ", "."),
        "up": ("Look ", " now!"),
        "down": ("Sit ", ", please."),
        "near": ("The store is ", "."),
        "far": ("The beach is ", "."),
    },
    "p1-u55": {
        "school": ("Walk to ", " together."),
        "hospital": ("The ", " is busy."),
        "shop": ("Visit the corner ", "."),
        "park": ("Meet at the ", "."),
        "restaurant": ("Pick a new ", "."),
        "hotel": ("Book a quiet ", "."),
        "library": ("Quiet inside the ", "."),
        "church": ("The old ", " stands."),
    },
    "p1-u56": {
        "drive": ("I ", " every morning."),
        "ride": ("Hop on for a ", "."),
        "arrive": ("We ", " at six."),
        "travel": ("I love to ", "."),
        "road": ("The ", " is closed."),
        "street": ("Cross the busy ", "."),
        "traffic": ("Heavy ", " today."),
        "commute": ("My ", " takes hours."),
    },
    "p1-u57": {
        "school": ("I love ", " days."),
        "class": ("Math ", " starts now."),
        "student": ("Every ", " is smart."),
        "teacher": ("Our ", " is kind."),
        "learn": ("We ", " every day."),
        "study": ("I ", " late nightly."),
        "read": ("Please ", " this book."),
        "write": ("", " your name here."),
    },
    "p1-u58": {
        "math": ("I love ", " class."),
        "science": ("", " explains the world."),
        "history": ("", " repeats often."),
        "art": ("Make ", " every day."),
        "music": ("Soft ", " plays here."),
        "book": ("Read this ", " tonight."),
        "pen": ("Lend me a ", "."),
        "paper": ("Pass the white ", "."),
    },
    "p1-u59": {
        "work": ("I ", " every weekday."),
        "job": ("I got a ", "!"),
        "boss": ("My ", " is great."),
        "lawyer": ("Ask a ", " first."),
        "engineer": ("She's an ", " now."),
        "scientist": ("Every ", " is curious."),
        "meeting": ("Long ", " today."),
        "retire": ("I plan to ", "."),
    },
    "p1-u60": {
        "dog": ("My ", " loves walks."),
        "cat": ("Our ", " naps daily."),
        "horse": ("The brown ", " runs."),
        "cow": ("The ", " mooed loudly."),
        "pig": ("Pink ", " is fat."),
        "sheep": ("A wooly ", " grazes."),
        "rabbit": ("Tiny ", " hops by."),
        "duck": ("The ", " swims fast."),
    },
    "p1-u61": {
        "lion": ("The ", " roars loud."),
        "tiger": ("A ", " stalks quietly."),
        "elephant": ("The ", " is huge."),
        "bear": ("A brown ", " appeared."),
        "wolf": ("A ", " howled tonight."),
        "fox": ("A red ", " appeared."),
        "eagle": ("The ", " soared high."),
        "monkey": ("A clever ", " escaped."),
    },
    "p1-u62": {
        "tree": ("An old ", " stands."),
        "flower": ("Pick a wild ", "."),
        "mountain": ("Climb the steep ", "."),
        "river": ("The ", " runs fast."),
        "ocean": ("Swim in the ", "."),
        "beach": ("Walk on the ", "."),
        "sun": ("The ", " shines brightly."),
        "moon": ("A full ", " tonight."),
        "spring": ("Flowers bloom in ", "."),
        "summer": ("Long ", " days now."),
        "fall": ("Leaves drop in ", "."),
        "winter": ("Cold ", " is coming."),
    },
    "p1-u63": {
        "rain": ("Heavy ", " all day."),
        "snow": ("Fresh ", " fell overnight."),
        "wind": ("Strong ", " today."),
        "cloud": ("A dark ", " appeared."),
        "lightning": ("Bright ", " flashed twice."),
        "thunder": ("Loud ", " rolled in."),
        "hot": ("Very ", " today!"),
        "cold": ("It's ", " out here."),
    },
    "p1-u65": {
        "football": ("Watch ", " every Sunday."),
        "basketball": ("Shoot some ", " hoops."),
        "baseball": ("Catch the ", " quickly."),
        "soccer": ("Kick the ", " ball."),
        "volleyball": ("Spike that ", " over."),
        "hockey": ("", " on cold ice."),
        "tennis": ("Quick ", " match today."),
        "golf": ("Long ", " game ahead."),
    },
    "p1-u66": {
        "draw": ("Let me ", " you."),
        "paint": ("We ", " on weekends."),
        "sing": ("", " the chorus loud."),
        "dance": ("Let's ", " all night."),
        "music": ("Soft ", " plays here."),
        "guitar": ("Play me the ", "."),
        "piano": ("Tune the old ", "."),
    },
    "p1-u67": {
        "party": ("Birthday ", " tonight!"),
        "birthday": ("Happy ", ", friend!"),
        "christmas": ("Merry ", ", everyone!"),
        "halloween": ("Spooky ", " night."),
        "thanksgiving": ("Happy ", " feast!"),
        "easter": ("", " eggs everywhere today."),
    },
    "p1-u68": {
        "america": ("Born in ", "."),
        "canada": ("", " is cold."),
        "mexican": ("Love ", " food."),
        "france": ("Visit ", " someday."),
        "germany": ("", " has good beer."),
        "china": ("", " is huge."),
        "japan": ("Travel to ", " next."),
    },
    "p1-u69": {
        "computer": ("Reboot the ", " now."),
        "phone": ("Charge my ", " please."),
        "tablet": ("My ", " is slow."),
        "laptop": ("Open the ", " here."),
        "camera": ("Bring your ", " along."),
        "tv": ("Turn the ", " off."),
        "keyboard": ("Type on the ", "."),
    },
    "p1-u70": {
        "internet": ("Check the ", " connection."),
        "email": ("Send me an ", "."),
        "text": ("", " me when ready."),
        "download": ("Please ", " this file."),
        "upload": ("", " the photos today."),
        "share": ("", " the link now."),
        "send": ("Quick, ", " it now."),
    },
    "p1-u71": {
        "can": ("I ", " do it."),
        "cannot": ("I ", " wait!"),
        "maybe": ("", " later, friend."),
        "important": ("Very ", " message here."),
        "right": ("You're ", ", always."),
        "wrong": ("Something feels ", "."),
        "future": ("Plan for the ", "."),
    },
    "p1-u72": {
        "allofsudden": ("", ", it rained."),
        "dontknow": ("I ", " yet."),
        "notyet": ("Done? ", "."),
        "letmesee": ("", " the photo."),
        "blowmind": ("That news will ", "."),
        "giveup": ("Don't ", " now."),
        "letgo": ("", " the past."),
        "wrapup": ("Time to ", " here."),
    },
}


def _legacy_sentences_by_word() -> dict[str, tuple[str, str]]:
    """First legacy sentence per word id (for re-homing after unit merges)."""
    by_word: dict[str, tuple[str, str]] = {}
    for words in _LEGACY_SENTENCES.values():
        for word_id, pair in words.items():
            by_word.setdefault(word_id, pair)
    return by_word


def _merge_sentences() -> dict[str, dict[str, tuple[str, str]]]:
    merged: dict[str, dict[str, tuple[str, str]]] = {}
    legacy_by_word = _legacy_sentences_by_word()
    for uid, words in _LEGACY_SENTENCES.items():
        merged[uid] = dict(words)
    for uid, words in SENTENCE_OVERRIDES.items():
        merged.setdefault(uid, {}).update(words)
    for unit in UNITS:
        uid = unit["id"]
        if uid in NO_FILLGAP_UNITS:
            continue
        merged.setdefault(uid, {})
        for word_id in unit["words"]:
            if word_id in merged[uid]:
                continue
            if word_id in legacy_by_word:
                merged[uid][word_id] = legacy_by_word[word_id]
    return merged


SENTENCES: dict[str, dict[str, tuple[str, str]]] = _merge_sentences()


def distractor_pool(unit_words: list[str], prior_pool: list[str]) -> list[str]:
    """Unit vocabulary plus earlier units (deduped, unit order first)."""
    return list(dict.fromkeys(unit_words + prior_pool))


def rotate_pick(answer: str, candidates: list[str], k: int) -> list[str]:
    """Deterministic rotation through `candidates` starting at the answer's position."""
    if len(candidates) <= k:
        return candidates
    if answer in candidates:
        start = candidates.index(answer) % len(candidates)
    else:
        start = sum(ord(c) for c in answer) % len(candidates)
    rotated = candidates[start:] + candidates[:start]
    return rotated[:k]


def semantic_distractor_candidates(answer: str, pool: list[str]) -> list[str]:
    """Peers in `pool` that share at least one semantic category with `answer`."""
    pool_set = set(pool)
    peers = semantic_distractor_peer_ids(answer) & pool_set
    peers.discard(answer)
    return sorted(peers)


def normalize_choice_count(count: int) -> int:
    """Recognition steps show two or four tiles — never an odd count."""
    return 4 if count > 2 else 2


def pick_distractors(
    answer: str,
    pool: list[str],
    k: int = 3,
    *,
    semantic: bool = False,
) -> list[str]:
    """Pick `k` distractor words from the unit's pool, excluding the answer."""
    if answer in PHRASE_IDS:
        # Phrase recognition tiles must all be phrases (learned or not).
        pool = sorted(PHRASE_IDS)
        semantic = False
    else:
        # Single-word fill-slot blanks must not offer phrase ids as tile choices.
        pool = [w for w in pool if w not in PHRASE_IDS]
    if semantic:
        peers = semantic_distractor_candidates(answer, pool)
        if len(peers) >= k:
            return rotate_pick(answer, peers, k)
        picked = rotate_pick(answer, peers, len(peers)) if peers else []
        remainder_pool = [w for w in pool if w not in picked and w != answer]
        remainder = pick_distractors(
            answer, remainder_pool, k - len(picked), semantic=False
        )
        return picked + remainder

    others = [w for w in pool if w != answer]
    if len(others) <= k:
        return others
    if answer in pool:
        start = pool.index(answer) % len(others)
    else:
        start = sum(ord(c) for c in answer) % len(others)
    rotated = others[start:] + others[:start]
    return rotated[:k]


def make_fill_gap_questions(unit: dict) -> list[dict]:
    unit_id = unit["id"]
    sentences = SENTENCES.get(unit_id)
    if sentences is None:
        raise SystemExit(f"Missing fillGap sentences dict for {unit_id}")

    questions = []
    for w in unit["words"]:
        if w not in sentences:
            continue
        before, after = sentences[w]
        questions.append({
            "sentenceBefore": before,
            "sentenceAfter": after,
            "answerWordId": w,
            "distractorWordIds": pick_distractors(w, unit["words"]),
        })
    return questions


def teach_meta_for_word(word: str, default: tuple[str, str]) -> tuple[str, str]:
    if word in PHRASE_IDS:
        return ("Watch this phrase", "Learn the full motion.")
    return default


def teach_step(word: str, title: str = "", prompt: str = "") -> dict:
    return {
        "kind": "teach",
        "wordId": word,
        "title": title,
        "prompt": prompt,
    }


def pick_step(
    kind: str,
    word: str,
    pool: list[str],
    prompt: str = "",
    choice_count: int | None = None,
    *,
    semantic: bool = False,
) -> dict:
    total_choices = normalize_choice_count(choice_count or 2)
    step = {
        "kind": kind,
        "answerWordId": word,
        "distractorWordIds": pick_distractors(
            word, pool, total_choices - 1, semantic=semantic
        ),
        "prompt": prompt,
        "choiceCount": total_choices,
    }
    return step


def fill_gap_step(question: dict) -> dict:
    return {
        "kind": "fillGap",
        **question,
    }




def display_word(word: str) -> str:
    if word in DISPLAY_OVERRIDES:
        return DISPLAY_OVERRIDES[word]
    return word.replace("_", " ").replace("-", " ").title()


def word_pick_video_step(word: str, pool: list[str], prompt: str = "") -> dict:
    return {
        **pick_step(
            "wordPickVideo",
            word,
            pool,
            prompt or f"Pick out {display_word(word)}.",
            2,
        ),
    }


def watch_then_pick_step(word: str, pool: list[str], prompt: str = "") -> dict:
    return {
        **pick_step("watchThenPick", word, pool, prompt or "What sign was that?", 2),
    }


def watch_choose_prompt(word: str) -> str:
    return "What phrase is this?" if word in PHRASE_IDS else "Which word is this?"


def intro_confirm_step(
    word: str,
    pool: list[str],
    *,
    choice_count: int = 2,
) -> dict:
    """Immediate recognition check after a teach step (answer = the new sign)."""
    step = watch_choose_step(word, pool, choice_count=choice_count)
    step["prompt"] = (
        "What phrase is this?" if word in PHRASE_IDS else "What sign is this?"
    )
    return step


def varied_confirm_step(
    word: str,
    pool: list[str],
    slot: int,
    *,
    choice_count: int = 2,
    avoid_watch_choose: bool = False,
) -> dict:
    """Spaced review check — rotate kinds away from back-to-back watchChoose."""
    if word in PHRASE_IDS:
        return translation_choose_step(word, pool, choice_count=choice_count)

    if avoid_watch_choose:
        if slot % 2 == 0:
            return word_pick_video_step(word, pool)
        return translation_choose_step(word, pool, choice_count=choice_count)

    pick = slot % 4
    if pick in (0, 2):
        return watch_choose_step(word, pool, choice_count=choice_count)
    if pick == 1:
        return word_pick_video_step(word, pool)
    return translation_choose_step(word, pool, choice_count=choice_count)


def watch_choose_step(word: str, pool: list[str], prompt: str = "", choice_count: int = 2) -> dict:
    return {
        **pick_step(
            "watchChoose",
            word,
            pool,
            prompt or watch_choose_prompt(word),
            choice_count,
            semantic=True,
        ),
    }


def translation_choose_step(
    word: str,
    pool: list[str],
    prompt: str = "",
    choice_count: int = 2,
) -> dict:
    return {
        **pick_step(
            "translationChoose",
            word,
            pool,
            prompt or "Choose the correct translation.",
            choice_count,
            semantic=True,
        ),
    }


def stone1_translation_choose_step(
    word: str, pool: list[str], *, choice_count: int = 2
) -> dict:
    """Stone 1 sign-to-meaning check — watch the sign, pick the English word."""
    return translation_choose_step(
        word,
        pool,
        prompt=STONE1_TRANSLATION_CHOOSE_PROMPT,
        choice_count=choice_count,
    )


def sign_sequence_components(phrase_id: str) -> list[str]:
    """Ordered signs for Build the Phrase — never the full phrase video as a tile."""
    raw = PHRASE_COMPONENTS.get(phrase_id, [])
    without_target = [c for c in raw if c != phrase_id]
    atomic = [c for c in without_target if c not in PHRASE_IDS]
    if len(atomic) >= 2:
        return atomic
    if len(without_target) >= 2:
        return without_target
    return list(raw)


def phrase_component_distractors(
    answer: str,
    phrase_id: str,
    *,
    prefer_taught: set[str] | None = None,
    max_count: int = 3,
) -> list[str]:
    """Wrong tiles drawn only from other signs in the same phrase."""
    components = PHRASE_COMPONENTS.get(phrase_id, [])
    pool = [c for c in components if c != answer and c not in PHRASE_IDS]
    if not pool:
        return []
    taught = prefer_taught or set()
    preferred = [c for c in pool if c in taught]
    remainder = [c for c in pool if c not in taught]
    ordered = preferred + remainder
    return ordered[:max_count]


def sign_sequence_distractors(
    components: list[str],
    pool: list[str],
    k: int,
) -> list[str]:
    """Wrong tiles for signSequence must be single signs, not other phrases."""
    if k <= 0:
        return []
    word_pool = sorted({w for w in pool if w not in PHRASE_IDS and w not in components})
    if not word_pool:
        return []
    anchor = components[0]
    return pick_distractors(anchor, word_pool, k, semantic=False)


def phrase_slot_distractors(
    answer: str,
    phrase_id: str,
    slot_index: int,
    pool: list[str],
    *,
    prefer_taught: set[str] | None = None,
    max_count: int = 1,
) -> list[str]:
    """Wrong tiles for phraseSlot: lesson vocabulary, never signs already shown in the strip."""
    if max_count <= 0:
        return []
    components = PHRASE_COMPONENTS.get(phrase_id, [])
    if slot_index < 0 or slot_index >= len(components):
        return []
    prefilled = {components[i] for i in range(len(components)) if i != slot_index}
    excluded = prefilled | {answer} | PHRASE_IDS | set(components)
    word_pool = sorted({w for w in pool if w not in excluded})
    if not word_pool:
        return []
    taught = prefer_taught or set()
    preferred = [w for w in word_pool if w in taught]
    remainder = [w for w in word_pool if w not in taught]
    ordered = preferred + remainder
    return pick_distractors(answer, ordered, max_count, semantic=True)


SIGN_SEQUENCE_PROMPT = "Complete this phrase."


def sign_sequence_step(
    phrase_id: str,
    sequence_word_ids: list[str],
    pool: list[str],
    prompt: str = "",
) -> dict:
    components = sign_sequence_components(phrase_id)
    if sequence_word_ids:
        subset = [c for c in sequence_word_ids if c in components]
        if len(subset) >= 2:
            components = subset
    distractors: list[str] = []
    if len(components) >= 3:
        distractors = sign_sequence_distractors(components, pool, k=1)
    return {
        "kind": "signSequence",
        "wordId": phrase_id,
        "sequenceWordIds": components,
        "distractorWordIds": distractors,
        "prompt": prompt or SIGN_SEQUENCE_PROMPT,
    }


def _phrase_slot_index(
    unit_sort_order: int,
    stone: int,
    phrase_id: str,
    component_count: int,
) -> int:
    seed = unit_sort_order + stone * 7 + sum(ord(c) for c in phrase_id)
    return seed % component_count


def phrase_slot_step(
    phrase_id: str,
    slot_index: int,
    introduced_components: set[str] | list[str],
    prompt: str = "",
    taught_set: set[str] | None = None,
    pool: list[str] | None = None,
) -> dict | None:
    components = PHRASE_COMPONENTS.get(phrase_id, [])
    if len(components) < 2:
        return None
    # v1: atomic word components only (no nested phrase ids as tiles).
    if any(c in PHRASE_IDS for c in components):
        return None
    slot_index = slot_index % len(components)
    answer = components[slot_index]
    intro = set(introduced_components) | set(taught_set or [])
    if answer not in intro:
        return None
    raw_pool = pool or list(intro)
    distractor_pool = [w for w in raw_pool if w in intro]
    distractors = phrase_slot_distractors(
        answer,
        phrase_id,
        slot_index,
        distractor_pool,
        prefer_taught=intro,
        max_count=1,
    )
    if not distractors:
        return None
    return {
        "kind": "phraseSlot",
        "wordId": phrase_id,
        "slotIndex": slot_index,
        "sequenceWordIds": components,
        "answerWordId": answer,
        "distractorWordIds": distractors,
        "prompt": prompt or "Which sign is missing?",
    }


def fill_slot_step(question: dict) -> dict:
    if question.get("answerWordId") in PHRASE_IDS:
        raise ValueError(
            f"fillSlot must not use phrase id {question.get('answerWordId')} as answer"
        )
    return {
        "kind": "fillSlot",
        **question,
    }


def match_pairs_step(
    pair_word_ids: list[str],
    prompt: str = "",
) -> dict:
    if len(pair_word_ids) < 2:
        raise ValueError("matchPairs needs at least two pairWordIds")
    return {
        "kind": "matchPairs",
        "answerWordId": pair_word_ids[0],
        "pairWordIds": pair_word_ids,
        "prompt": prompt or "Match signs with translations.",
    }


QUIZ_KINDS = frozenset(
    {"watchChoose", "translationChoose", "fillSlot", "wordPickVideo"}
)
SIGN_TO_WORD_KINDS = frozenset({"watchChoose", "translationChoose"})
WORD_TO_SIGN_KINDS = frozenset({"wordPickVideo"})
MAX_CONSECUTIVE_SAME_KIND = 1
RHYTHM_BREAK_KINDS = frozenset(
    {"teach", "matchPairs", "signSequence", "phraseSlot", "fillSlot"}
)
# After these beats, emit at most one queued phrase block so phrases land mid-lesson.
PHRASE_SPRINKLE_BEATS = frozenset(
    {
        "recognitionQuiz",
        "videoPickChallenge",
        "translationChoose",
        "yourTurn",
        "funMixed",
        "crossUnitReview",
        "useInContext",
        "phraseSprinkle",
    }
)

# Universal Unit Framework stone arcs. Stone 1 teaches + locks in; Stone 2 uses
# signs in context; Stone 3 is a mastery mix with cross-unit review.
STONE_BEATS: dict[int, list[str]] = {
    1: [
        "newSignTeach",
        "newSignTeach",
        "translationChoose",
        "recognitionQuiz",
        "newSignTeach",
        "translationChoose",
        "matchPairs",
        "recognitionQuiz",
        "newSignTeach",
        "useInContext",
        "recognitionQuiz",
        "newSignTeach",
        "videoPickChallenge",
        "aslTip",
        "funMixed",
        "matchPairs",
        "recognitionQuiz",
        "yourTurn",
        "funMixed",
    ],
    2: [
        "warmUp",
        "newSignTeach",
        "translationChoose",
        "recognitionQuiz",
        "warmUp",
        "recognitionQuiz",
        "translationChoose",
        "videoPickChallenge",
        "useInContext",
        "fillSlotPad",
        "phraseSprinkle",
        "matchPairs",
        "yourTurn",
        "funMixed",
        "recognitionQuiz",
        "matchPairs",
        "useInContext",
        "fillSlotPad",
        "aslTip",
        "phraseSprinkle",
        "crossUnitReview",
    ],
    3: [
        "warmUp",
        "crossUnitReview",
        "recognitionQuiz",
        "translationChoose",
        "matchPairs",
        "videoPickChallenge",
        "crossUnitReview",
        "translationChoose",
        "funMixed",
        "useInContext",
        "aslTip",
        "fillSlotPad",
        "warmUp",
        "recognitionQuiz",
        "matchPairs",
        "translationChoose",
        "crossUnitReview",
        "funMixed",
    ],
}

MIN_MATCH_PAIRS_ELIGIBLE = 2

MIN_UNIQUE_ANSWERS_PER_STONE = 10
MAX_PATH_REVIEW_ANSWERS_STONE1 = 3
PRIOR_STONE_REVIEW_SHARE_CAP = 0.35

# Per-stone repetition / spacing (single source of truth).
STONE_REPETITION_RULES: dict[int, dict[str, int]] = {
    1: {
        "max_answer_reps": 2,
        "density_window": 8,
        "density_max_in_window": 2,
        "min_answer_gap": 6,
        "recent_answer_exclusion": 6,
    },
    2: {
        "max_answer_reps": 2,
        "density_window": 8,
        "density_max_in_window": 2,
        "min_answer_gap": 4,
        "recent_answer_exclusion": 5,
    },
    3: {
        "max_answer_reps": 2,
        "density_window": 8,
        "density_max_in_window": 2,
        "min_answer_gap": 4,
        "recent_answer_exclusion": 5,
    },
}

STONE1_ANSWER_GAP = STONE_REPETITION_RULES[1]["min_answer_gap"]
MAX_ANSWER_REPS_STONE1 = STONE_REPETITION_RULES[1]["max_answer_reps"]
MAX_ANSWER_REPS_STONE234 = STONE_REPETITION_RULES[2]["max_answer_reps"]
DENSITY_WINDOW_STONE1 = STONE_REPETITION_RULES[1]["density_window"]
DENSITY_WINDOW_STONE234 = STONE_REPETITION_RULES[2]["density_window"]
DENSITY_MAX_IN_WINDOW = STONE_REPETITION_RULES[2]["density_max_in_window"]
DENSITY_MAX_IN_WINDOW_STONE1 = STONE_REPETITION_RULES[1]["density_max_in_window"]
RECENT_ANSWER_EXCLUSION = STONE_REPETITION_RULES[2]["recent_answer_exclusion"]


def repetition_rule(stone: int, key: str) -> int:
    rules = STONE_REPETITION_RULES.get(stone, STONE_REPETITION_RULES[3])
    return rules[key]

# Stone-weighted padding kinds — cap pick-trinity share; interleave rhythm breaks.
STONE_PAD_KIND_WEIGHTS: dict[int, list[str]] = {
    1: [
        "translationChoose",
        "matchPairs",
        "wordPickVideo",
        "translationChoose",
        "matchPairs",
        "translationChoose",
        "wordPickVideo",
        "fillSlot",
    ],
    2: [
        "watchChoose",
        "translationChoose",
        "matchPairs",
        "watchChoose",
        "wordPickVideo",
        "fillSlot",
        "watchChoose",
        "matchPairs",
    ],
    3: [
        "watchChoose",
        "wordPickVideo",
        "matchPairs",
        "fillSlot",
        "translationChoose",
        "wordPickVideo",
        "matchPairs",
        "fillSlot",
    ],
}

# Never dropped when trimming a lesson to the step cap.
PROTECTED_STEP_KINDS = frozenset(
    {
        "aslTip",
        "yourTurn",
        "matchPairs",
        "signSequence",
        "phraseSlot",
        "teach",
    }
)


def meaning_pick_step(word: str, pool: list[str], fill_by_word: dict, prompt: str = "") -> dict:
    if not prompt and word in fill_by_word:
        question = fill_by_word[word]
        sentence = f"{question['sentenceBefore']}____{question['sentenceAfter']}".strip()
        prompt = f"Which sign fits here? {sentence}"
    return {
        **pick_step("meaningPick", word, pool, prompt or f"Choose the sign for {display_word(word)}.", 2),
        "title": "Meaning check",
    }


def same_different_step(word: str, pool: list[str], make_same: bool, prompt: str = "") -> dict:
    comparison = word
    correct = "same"
    if not make_same:
        comparison = pick_distractors(word, pool, 1)[0]
        correct = "different"
    return {
        "kind": "sameDifferent",
        "wordId": word,
        "comparisonWordId": comparison,
        "correctChoice": correct,
        "prompt": prompt or "Choose an answer.",
    }


def self_sign_step(word: str) -> dict:
    return {
        "kind": "selfSign",
        "wordId": word,
        "title": "Now sign it yourself.",
        "prompt": "Practice with the video. Tap Done when you've got it.",
    }


# ASL tips live in asl_tips_catalog.py (stable ids for once-per-learner display).


def asl_tip_step(tip: dict[str, str]) -> dict:
    step: dict = {
        "kind": "aslTip",
        "tipId": tip["id"],
        "prompt": tip["text"],
    }
    word_id = tip.get("wordId")
    if word_id:
        step["wordId"] = word_id
    return step


def your_turn_step(word: str) -> dict:
    return {
        "kind": "yourTurn",
        "wordId": word,
        "title": "Your Turn",
        "prompt": "Record yourself signing, then compare with the example.",
    }


def module_lesson(
    unit: dict,
    lesson_id: str,
    title: str,
    sort_order: int,
    steps: list[dict],
    display_title: str | None = None,
    word_ids: list[str] | None = None,
) -> dict:
    lesson = {
        "id": f"{unit['id']}-{lesson_id}",
        "title": title,
        "type": "module",
        "sortOrder": sort_order,
        "wordIds": word_ids if word_ids is not None else unit["words"],
        "steps": steps,
    }
    if display_title:
        lesson["displayTitle"] = display_title
    return lesson


LESSON_TITLES = {
    1: "Learn & Lock In",
    2: "Use It",
    3: "Challenge Mix",
}

STEP_PROMPTS = {
    "watchPick2": "Tap the matching word.",
    "watchPick4": "Which word matches this sign?",
    "wordPickVideo": "",
    "watchThenPick": "What sign was that?",
    "watchChoose": "Which word is this?",
    "translationChoose": "Choose the correct translation.",
    "fillSlot": "Fill in the missing sign.",
    "matchPairs": "Tap the matching pair.",
}

WATCH_CHOOSE_PHRASE_FRAMES = [
    "What phrase is this?",
    "Choose the correct phrase.",
]

WORD_PICK_VIDEO_PHRASE_FRAMES = [
    "Match this phrase.",
]

PROMPT_FRAMES: dict[str, list[str]] = {
    "watchChoose": [
        "What sign is this?",
        "Choose the correct sign.",
    ],
    "fillSlot": [
        "Fill the blank in the sentence.",
        "What sign belongs here?",
        "Choose the missing sign.",
    ],
    "phraseSlot": [
        "Which sign is missing?",
    ],
    "signSequence": [
        SIGN_SEQUENCE_PROMPT,
    ],
    "translationChoose": [
        "Choose the correct translation.",
        "What does this sign mean?",
        "Pick the meaning.",
    ],
    "matchPairs": [
        "Tap the matching pair.",
        "Match signs with translations.",
        "Pair each sign with its word.",
        "Connect signs to meanings.",
        "Match the signs and words.",
    ],
    "wordPickVideo": [
        "Pick out {word}.",
        "Find {word}.",
        "Choose {word}.",
        "Which video shows {word}?",
        "Match this sign: {word}.",
    ],
}

NEW_SIGN_INTRODUCTION = [
    "New sign!",
    "First time seeing this",
]

PHRASE_INTRODUCTION = [
    "Learn a new phrase!",
    "Watch this phrase!",
    "Here's a new phrase!",
    "See the whole sign!",
]

INTRODUCTION_PROMPT_KINDS = frozenset({"wordPickVideo"})

RUNTIME_INTRO_KINDS = frozenset(
    {
        "watchChoose",
        "translationChoose",
        "wordPickVideo",
        "watchPick2",
        "watchPick4",
        "watchThenPick",
        "meaningPick",
    }
)

FRAMED_PROMPT_KINDS = frozenset(PROMPT_FRAMES.keys())


def introduction_prompt(word: str, lesson_id: str, step_index: int) -> str:
    if word in PHRASE_IDS:
        seed = zlib.adler32(f"{lesson_id}:intro:{step_index}:{word}".encode()) & 0xFFFFFFFF
        return PHRASE_INTRODUCTION[seed % len(PHRASE_INTRODUCTION)]
    seed = zlib.adler32(f"{lesson_id}:intro:{step_index}:{word}".encode()) & 0xFFFFFFFF
    return NEW_SIGN_INTRODUCTION[seed % len(NEW_SIGN_INTRODUCTION)]


def prompt_framing(
    kind: str,
    lesson_id: str,
    step_index: int,
    word: str | None = None,
) -> str:
    if kind == "watchChoose" and word and word in PHRASE_IDS:
        options = WATCH_CHOOSE_PHRASE_FRAMES
    elif kind == "wordPickVideo" and word and word in PHRASE_IDS:
        options = WORD_PICK_VIDEO_PHRASE_FRAMES
    else:
        options = PROMPT_FRAMES.get(kind, [])
    if not options:
        return ""
    seed = zlib.adler32(f"{lesson_id}:{step_index}:{kind}".encode()) & 0xFFFFFFFF
    template = options[seed % len(options)]
    if kind == "wordPickVideo" and word and word not in PHRASE_IDS:
        return template.replace("{word}", display_word(word))
    return template


def apply_prompt_framing(
    lesson_id: str,
    steps: list[dict],
    introduced_on_path: set[str] | None = None,
    lesson_words: list[str] | None = None,
) -> tuple[list[dict], set[str]]:
    """Apply lesson prompts. New-sign / new-phrase intros are path-unique."""
    out: list[dict] = []
    introduced = set(introduced_on_path or set())
    lesson_vocab = set(lesson_words or [])
    for index, step in enumerate(steps):
        framed = dict(step)
        kind = framed["kind"]
        word = framed.get("answerWordId") or framed.get("wordId")
        if kind == "teach":
            teach_word = framed.get("wordId")
            if teach_word:
                introduced.add(teach_word)
                if not framed.get("title") or not framed.get("prompt"):
                    title, prompt = teach_meta_for_word(teach_word, NEW_SIGN_TEACH)
                    framed.setdefault("title", title)
                    framed.setdefault("prompt", prompt)
        if kind in {"signSequence", "phraseSlot"}:
            for wid in framed.get("sequenceWordIds", []):
                if wid:
                    introduced.add(wid)
            phrase = framed.get("wordId")
            if phrase:
                introduced.add(phrase)
            slot_answer = framed.get("answerWordId")
            if slot_answer and kind == "phraseSlot":
                introduced.add(slot_answer)
        if kind in INTRODUCTION_PROMPT_KINDS and word and word not in introduced:
            if not lesson_vocab or word in lesson_vocab:
                introduced.add(word)
                framed["prompt"] = introduction_prompt(word, lesson_id, index)
        elif kind in FRAMED_PROMPT_KINDS:
            framed["prompt"] = prompt_framing(kind, lesson_id, index, word)
        elif kind in INTRODUCTION_PROMPT_KINDS and word:
            framed["prompt"] = prompt_framing(kind, lesson_id, index, word)
        out.append(framed)
    return out, introduced


def pin_stone1_meaning_pick_prompts(steps: list[dict]) -> list[dict]:
    """Pin the first two stone-1 translation checks to Pick the meaning."""
    out = list(steps)
    tc_indices = [
        index for index, step in enumerate(out) if step.get("kind") == "translationChoose"
    ]
    for index in tc_indices[:STONE1_MIN_TRANSLATION_CHOOSE]:
        step = dict(out[index])
        step["prompt"] = STONE1_TRANSLATION_CHOOSE_PROMPT
        out[index] = step
    return out


NEW_SIGN_TEACH = ("New sign!", "Continue when it feels familiar.")

STONE_TEACH_META = {
    1: NEW_SIGN_TEACH,
    2: NEW_SIGN_TEACH,
    3: NEW_SIGN_TEACH,
    4: NEW_SIGN_TEACH,
}


class CurriculumState:
    """Tracks cumulative taught vocabulary across the ordered home path."""

    def __init__(self) -> None:
        self.ever_taught: set[str] = set()
        self.taught_set: set[str] = set()
        self.sequenced_phrases: set[str] = set()
        self.prior_pool: list[str] = []
        self.introduced_words: set[str] = set()
        self.phrase_fill_emitted: set[tuple[str, str]] = set()
        self.asl_tip_used_ids: set[str] = set()
        self.asl_tip_cursor: int = 0
        self.ordered_units: list[dict] = []

    def register_unit(self, unit: dict) -> None:
        for word in unit["words"]:
            if word not in self.prior_pool:
                self.prior_pool.append(word)


class LessonBuilder:
    def __init__(
        self,
        unit: dict,
        state: CurriculumState,
        fill_by_word: dict[str, dict],
        teach_meta: tuple[str, str],
        watch_reinforcement: int = 2,
    ) -> None:
        self.unit = unit
        self.state = state
        self.fill_by_word = fill_by_word
        self.teach_meta = teach_meta
        self.pool = distractor_pool(
            list(dict.fromkeys(unit["words"] + state.prior_pool + list(state.taught_set))),
            [],
        )
        self.steps: list[dict] = []
        self.last_kind: str | None = None
        self._graded_streak = 0
        self._same_quiz_kind_streak = 0
        self._quiz_slot = 0
        self._answer_counts: Counter[str] = Counter()
        self.stone = 1
        self.watch_reinforcement = max(1, watch_reinforcement)
        self._phrase_cluster_active = False
        self.introduced_in_lesson: set[str] = set()
        self._last_new_intro_word: str | None = None
        self._intro_streak = 0
        self._pending_intro_words: list[str] = []
        self._requiz_blocked_until: dict[str, int] = {}
        self._phrase_component_cooldown_until: dict[str, int] = {}
        self._recognition_modality_by_word: dict[str, str] = {}

    def _would_be_new_sign_intro(self, step: dict) -> bool:
        kind = step.get("kind")
        if kind not in RUNTIME_INTRO_KINDS:
            return False
        word = step.get("answerWordId")
        if not word or word in PHRASE_IDS:
            return False
        if word not in self.unit["words"]:
            return False
        if word in self.state.introduced_words:
            return False
        return word not in self.introduced_in_lesson

    def _should_follow_up_after_intro(self, word: str) -> bool:
        """Defer recognition checks until an intro block ends (see _flush_pending_intro_batch)."""
        _ = word
        return False

    def _register_pending_intro(self, word: str) -> None:
        self._intro_streak += 1
        self._pending_intro_words.append(word)

    def _flush_pending_intro_batch(self) -> None:
        """Mixed recognition checks after each new-sign intro (never back-to-back)."""
        words = self._pending_intro_words
        if not words:
            self._intro_streak = 0
            return
        self._pending_intro_words = []
        self._intro_streak = 0
        choice_count = 4 if self.stone >= 3 else 2
        for i, word in enumerate(words):
            if len(self.steps) >= self._step_limit():
                self._pending_intro_words.extend(words[i:])
                break
            slot = len(self.steps) + self._slot + i
            if i == 0:
                step = intro_confirm_step(word, self.pool, choice_count=2)
            elif self.stone <= 2:
                if slot % 2 == 0:
                    step = watch_choose_step(word, self.pool, choice_count=2)
                else:
                    step = translation_choose_step(
                        word, self.pool, choice_count=choice_count
                    )
            elif slot % 3 == 0:
                step = word_pick_video_step(word, self.pool)
            elif slot % 3 == 1:
                step = watch_choose_step(word, self.pool, choice_count=choice_count)
            else:
                step = translation_choose_step(
                    word, self.pool, choice_count=choice_count
                )
            self._append_quiz(step, _spacing_guard=False)

    def _record_step_introduction(self, step: dict) -> None:
        if step.get("kind") == "teach":
            word = step.get("wordId")
            if word:
                self.introduced_in_lesson.add(word)
        answer = step.get("answerWordId")
        if answer:
            self.introduced_in_lesson.add(answer)
        for wid in step.get("pairWordIds", []):
            if wid:
                self.introduced_in_lesson.add(wid)
        for wid in step.get("questionWordIds", []):
            if wid:
                self.introduced_in_lesson.add(wid)
        phrase = step.get("wordId")
        if step.get("kind") in {"signSequence", "phraseSlot"}:
            for wid in step.get("sequenceWordIds", []):
                if wid:
                    self.introduced_in_lesson.add(wid)
            if phrase := step.get("wordId"):
                self.introduced_in_lesson.add(phrase)

    def _introduced_pool(self) -> set[str]:
        lesson_start = getattr(self, "_lesson_start_introduced", set())
        return lesson_start | self.introduced_in_lesson

    def match_pair_eligible(self) -> list[str]:
        pool = self._introduced_pool()
        return [w for w in self.unit["words"] if w in pool and w not in PHRASE_IDS]

    def _step_limit(self) -> int:
        return STONE_MAX_STEPS.get(self.stone, MAX_MODULE_STEPS)

    def _step_target(self) -> int:
        return STONE_MIN_STEPS.get(self.stone, MIN_MODULE_STEPS)

    def _note_rhythm(self, kind: str) -> None:
        if kind in RHYTHM_BREAK_KINDS:
            self._graded_streak = 0
            self._same_quiz_kind_streak = 0
        elif kind in QUIZ_KINDS:
            self._graded_streak += 1
            if kind == self.last_kind:
                self._same_quiz_kind_streak += 1
            else:
                self._same_quiz_kind_streak = 1

    def _maybe_break_rhythm(self) -> bool:
        if self._graded_streak < 5 and self._same_quiz_kind_streak < 2:
            return False
        word = self._pick_review_word()
        if not word:
            return False
        if self._graded_streak % 2 == 0:
            step = translation_choose_step(word, self.pool, choice_count=4)
        else:
            step = word_pick_video_step(word, self.pool)
        step = self._coerce_step_pacing(step)
        self.append(step)
        return True

    def append(self, step: dict) -> None:
        kind = step["kind"]
        if kind == "matchPairs":
            eligible = set(self.match_pair_eligible())
            pairs = [w for w in step.get("pairWordIds", []) if w in eligible]
            if len(pairs) < 2:
                return
            step = {**step, "pairWordIds": pairs, "answerWordId": pairs[0]}
            kind = step["kind"]
            if self.steps and self.steps[-1].get("kind") == "matchPairs":
                step = _match_pairs_alternate_step(step, self.pool, len(self.steps))
                kind = step["kind"]
                if kind != "matchPairs":
                    self._append_quiz(step, _spacing_guard=False)
                    return
        if kind == "teach":
            word = step.get("wordId")
            if not word:
                return
            if self.steps and self.steps[-1].get("kind") == "teach":
                prev_word = self.steps[-1].get("wordId")
                if (
                    prev_word
                    and prev_word != word
                    and len(self.steps) < self._step_limit()
                ):
                    if self.stone == 1:
                        orphan_confirm = word_pick_video_step(prev_word, self.pool)
                        orphan_confirm["prompt"] = (
                            "What phrase is this?"
                            if prev_word in PHRASE_IDS
                            else "What sign is this?"
                        )
                        self._append_quiz(orphan_confirm, _spacing_guard=False)
                    else:
                        self._append_quiz(
                            intro_confirm_step(prev_word, self.pool, choice_count=2),
                            _spacing_guard=False,
                        )
            if word in self.state.ever_taught and word in self.introduced_in_lesson:
                return
            self._maybe_break_rhythm()
            self.register_taught_word(word)
            self.steps.append(step)
            self.introduced_in_lesson.add(word)
            self._note_rhythm(kind)
            self.last_kind = kind
            return
        if kind == "fillSlot":
            phrase_id = step.get("wordId")
            answer = step.get("answerWordId")
            if (
                phrase_id in PHRASE_IDS
                and answer
                and (self.unit["id"], answer) in self.state.phrase_fill_emitted
            ):
                return
        self._assert_graded_taught(step)
        self.steps.append(step)
        self._record_step_introduction(step)
        self._mark_phrase_fill_emitted(step)
        self._record_answer_use(step)
        self._note_rhythm(kind)
        self.last_kind = kind
        if kind == "signSequence":
            phrase_id = step.get("wordId")
            if phrase_id:
                cooldown = self._graded_step_count() + 4
                for component in sign_sequence_components(phrase_id):
                    self._phrase_component_cooldown_until[component] = cooldown

    def register_taught_word(self, word: str) -> None:
        """Lesson-local taught tracking (path state commits in build_stone_steps)."""
        self.state.taught_set.add(word)

    def _assert_graded_taught(self, step: dict) -> None:
        kind = step["kind"]
        if kind in {"signSequence", "phraseSlot"}:
            for wid in step.get("sequenceWordIds", []):
                if wid not in self.state.taught_set:
                    raise ValueError(
                        f"{kind} component {wid} not taught in {self.unit['id']}"
                    )
            if kind == "phraseSlot":
                for wid in (
                    {step.get("answerWordId")}
                    | set(step.get("distractorWordIds", []))
                ):
                    if wid and wid not in self._introduced_pool():
                        raise ValueError(
                            f"phraseSlot choice {wid} not introduced in lesson"
                        )
            return
        if kind == "matchPairs":
            eligible = set(self.match_pair_eligible())
            for wid in step.get("pairWordIds", []):
                if wid not in eligible:
                    raise ValueError(f"matchPairs word {wid} not introduced in lesson")
            return
        answer = step.get("answerWordId")
        if answer and kind not in {"teach", "selfSign"}:
            if answer not in self.state.taught_set:
                raise ValueError(f"{kind} answer {answer} not in taught_set")
            if kind in QUIZ_KINDS and answer not in self._introduced_pool():
                if kind != "watchChoose":
                    raise ValueError(
                        f"{kind} answer {answer} quizzed before new-sign introduction"
                    )

    def _max_teach_confirm_pairs(self) -> int:
        return (
            MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS_STONE1
            if self.stone == 1
            else MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS
        )

    def _break_teach_confirm_streak_if_needed(self) -> None:
        """Insert a varied review step before another teach→confirm pair."""
        if _trailing_teach_confirm_pairs(self.steps) < self._max_teach_confirm_pairs():
            return
        if len(self.steps) >= self._step_limit():
            return
        if self._append_review_pad():
            return
        word = self._pick_review_word() or self.last_taught_word
        if not word:
            return
        slot = len(self.steps) + self._slot
        self._append_quiz(
            varied_confirm_step(
                word,
                self.pool,
                slot,
                choice_count=2,
                avoid_watch_choose=True,
            )
        )

    def append_teach_block(self, word: str) -> None:
        if self.stone == 3:
            return
        if word in self.state.ever_taught or word in self.introduced_in_lesson:
            return
        if len(self.steps) > self._step_limit() - 2:
            return
        self._break_teach_confirm_streak_if_needed()
        title, prompt = teach_meta_for_word(word, self.teach_meta)
        self.append(teach_step(word, title=title, prompt=prompt))
        self.last_taught_word = word
        if len(self.steps) < self._step_limit():
            if self.stone == 1:
                slot = len(self.steps) + self._slot
                self._slot += 1
                if word in PHRASE_IDS:
                    confirm = intro_confirm_step(word, self.pool, choice_count=2)
                else:
                    pick = slot % 3
                    tc_choices = 3 if len(self.introduced_in_lesson) >= 3 else 2
                    if pick == 0:
                        confirm = intro_confirm_step(word, self.pool, choice_count=2)
                    elif pick == 1:
                        confirm = stone1_translation_choose_step(
                            word, self.pool, choice_count=tc_choices
                        )
                    else:
                        confirm = word_pick_video_step(word, self.pool)
                self._append_quiz(confirm)
            else:
                slot = len(self.steps) + self._slot
                self._slot += 1
                pick = slot % 3
                if pick == 0:
                    confirm = intro_confirm_step(word, self.pool, choice_count=2)
                elif pick == 1:
                    choice_count = 4 if self.stone >= 2 else 2
                    confirm = translation_choose_step(
                        word, self.pool, choice_count=choice_count
                    )
                else:
                    confirm = word_pick_video_step(word, self.pool)
                self._append_quiz(confirm)
        gap = repetition_rule(self.stone, "min_answer_gap")
        self._requiz_blocked_until[word] = self._graded_step_count() + gap
        if word in PHRASE_CONTEXT_SIGN_SEQUENCES.get(self.unit["id"], {}):
            self._append_phrase_context_sign_sequence(word)

    def taught_words(self) -> list[str]:
        return [w for w in self.unit["words"] if w in self.state.taught_set]

    def untaught_words(self) -> list[str]:
        if self.stone == 3:
            return []
        subsets = UNIT_STONE_WORD_SUBSETS.get(self.unit["id"])
        if subsets and 1 <= self.stone <= len(subsets):
            scope = [w for w in subsets[self.stone - 1] if w not in PHRASE_IDS]
        else:
            scope = [w for w in self.unit["words"] if w not in PHRASE_IDS]
        return [w for w in scope if w not in self.state.ever_taught]

    def next_taught_word(self) -> str | None:
        return self._pick_least_used_word(self._eligible_quiz_words())

    def _stone_subset_vocab(self) -> list[str]:
        subsets = UNIT_STONE_WORD_SUBSETS.get(self.unit["id"])
        if subsets and 1 <= self.stone <= len(subsets):
            return [w for w in subsets[self.stone - 1] if w not in PHRASE_IDS]
        return [w for w in self.unit["words"] if w not in PHRASE_IDS]

    def _append_compact_intro(self, word: str) -> None:
        """Teach a new sign plus an immediate recognition confirm."""
        if word in self.state.ever_taught:
            return
        self.append_teach_block(word)

    def _introduce_stone_subset_vocab(self) -> None:
        """Front-load stone-subset words on Stone 2; Stone 1 uses beat arcs instead."""
        if self.stone != 2:
            return
        reserve = max(3, self._fill_untaught_reserve)
        for word in self._stone_subset_vocab():
            if word in self.state.ever_taught:
                continue
            if len(self.steps) >= self._step_limit() - reserve:
                break
            self._append_compact_intro(word)

    def _ensure_stone_vocab_coverage(self, min_per_word: int) -> None:
        """Deprecated — replaced by _ensure_min_unique_answer_words / _cap_answer_repetition."""
        _ = min_per_word

    def _stone1_path_review_pool(self) -> list[str]:
        if self.stone != 1 or self.unit["sortOrder"] <= 1:
            return []
        return stone1_review_candidates(
            self.unit["sortOrder"],
            self.state.prior_pool,
            self._stone_subset_vocab(),
            MAX_PATH_REVIEW_ANSWERS_STONE1,
        )

    def _min_unique_answer_target(self) -> int:
        pool_size = len(self._stone_subset_vocab()) if self.stone == 1 else len(
            [w for w in self.unit["words"] if w not in PHRASE_IDS]
        )
        return min(MIN_UNIQUE_ANSWERS_PER_STONE, pool_size, len(self.unit["words"]))

    def _unique_graded_answers(self) -> set[str]:
        answers: set[str] = set()
        for step in self.steps:
            answers.update(_graded_answer_word_ids(step))
        return answers

    def _varied_confirm_quiz(self, word: str, slot: int) -> dict:
        if self.stone <= 2:
            if slot % 2 == 0:
                return watch_choose_step(word, self.pool, choice_count=2)
            return word_pick_video_step(word, self.pool)
        pick = slot % 4
        if pick in (0, 1):
            return word_pick_video_step(word, self.pool)
        if pick == 2:
            return watch_choose_step(word, self.pool, choice_count=2)
        return translation_choose_step(word, self.pool, choice_count=2)

    def _ensure_subset_words_answered(self) -> None:
        """Stone 1: every subset word must appear as a graded answer at least once."""
        if self.stone != 1:
            return
        for word in self._stone_subset_vocab():
            if word in PHRASE_IDS or word in self._unique_graded_answers():
                continue
            if word not in self.introduced_in_lesson:
                continue
            while len(self.steps) >= self._step_limit() and not self._make_room_for_step():
                break
            if len(self.steps) >= self._step_limit():
                break
            self._append_quiz(word_pick_video_step(word, self.pool))

    def _ensure_min_unique_answer_words(self, min_unique: int = MIN_UNIQUE_ANSWERS_PER_STONE) -> None:
        """Append one varied quiz per missing answer word (intro first if needed)."""
        target = min(self._min_unique_answer_target(), min_unique)
        missing: list[str] = []
        seen = self._unique_graded_answers()
        subset = self._stone_subset_vocab()
        pool = list(subset)
        if self.stone == 1:
            for word in self._stone1_path_review_pool():
                if word not in pool:
                    pool.append(word)
        for word in pool:
            if word in PHRASE_IDS:
                if word not in self.introduced_in_lesson:
                    continue
            if word not in seen:
                missing.append(word)
        for word in missing:
            if len(self._unique_graded_answers()) >= target:
                break
            if len(self.steps) >= self._step_limit():
                break
            if self.stone > 1 and word not in self.introduced_in_lesson:
                continue
            if word not in self.introduced_in_lesson:
                if self.stone == 1 and word not in subset:
                    continue
                if word not in self.state.ever_taught:
                    self._append_compact_intro(word)
                else:
                    self.register_taught_word(word)
                    if self.stone == 1:
                        self._append_quiz(word_pick_video_step(word, self.pool))
                    else:
                        self._append_quiz(
                            watch_choose_step(word, self.pool, choice_count=2)
                        )
            if len(self.steps) >= self._step_limit():
                break
            if word not in self.state.taught_set:
                continue
            if word in self._unique_graded_answers():
                continue
            slot = len(self.steps)
            self._append_quiz(self._varied_confirm_quiz(word, slot))

    def _graded_answer_counts(self) -> Counter[str]:
        counts: Counter[str] = Counter()
        for step in self.steps:
            for answer in _graded_answer_word_ids(step):
                counts[answer] += 1
        return counts

    def _rebuild_match_pairs_step(
        self, step: dict, counts: Counter[str], max_per_word: int
    ) -> dict | None:
        eligible = self.match_pair_eligible()
        if len(eligible) < 2:
            return None
        pair_count = len(step.get("pairWordIds") or [])
        count = min(max(pair_count, 2), len(eligible))
        if self.stone >= 3:
            count = min(3, count)
        else:
            count = min(2, count)

        def board_score(words: list[str]) -> tuple[int, int]:
            return (max(counts.get(w, 0) for w in words), sum(counts.get(w, 0) for w in words))

        best: list[str] | None = None
        best_score: tuple[int, int] | None = None
        for candidate_words in (
            self._pick_match_pair_words(count, eligible),
            sorted(eligible, key=lambda w: counts.get(w, 0))[:count],
        ):
            candidate_words = list(dict.fromkeys(candidate_words))
            if len(candidate_words) < 2:
                continue
            projected = counts.copy()
            for old in _graded_answer_word_ids(step):
                projected[old] -= 1
            for word in candidate_words:
                projected[word] += 1
            if any(projected[w] > max_per_word for w in candidate_words):
                continue
            score = board_score(candidate_words)
            if best is None or score < best_score:
                best = candidate_words
                best_score = score
        if not best:
            return None
        return match_pairs_step(
            best,
            step.get("prompt") or STEP_PROMPTS["matchPairs"],
        )

    def _cap_answer_repetition(self, max_per_word: int | None = None) -> None:
        if max_per_word is None:
            max_per_word = repetition_rule(self.stone, "max_answer_reps")
        removable_kinds = frozenset(
            {
                "watchChoose",
                "wordPickVideo",
                "translationChoose",
                "fillSlot",
                "fillGap",
                "matchPairs",
            }
        )
        for _ in range(len(self.steps) * 3):
            counts = self._graded_answer_counts()
            over = {w for w, c in counts.items() if c > max_per_word}
            if not over:
                break

            changed = False
            for idx in range(len(self.steps) - 1, -1, -1):
                step = self.steps[idx]
                if step.get("kind") != "matchPairs":
                    continue
                pairs = step.get("pairWordIds") or []
                if not any(word in over for word in pairs):
                    continue
                rebuilt = self._rebuild_match_pairs_step(step, counts, max_per_word)
                if rebuilt:
                    self.steps[idx] = rebuilt
                    changed = True
                    break
                self.steps.pop(idx)
                changed = True
                break
            if changed:
                continue

            drop_idx = None
            for idx in range(len(self.steps) - 1, -1, -1):
                step = self.steps[idx]
                if step.get("kind") not in removable_kinds:
                    continue
                answers = _graded_answer_word_ids(step)
                if any(counts.get(answer, 0) > max_per_word for answer in answers):
                    drop_idx = idx
                    break
            if drop_idx is None:
                break
            dropped = self.steps.pop(drop_idx)
            for answer in _graded_answer_word_ids(dropped):
                counts[answer] -= 1

    def _answer_last_indices(self) -> dict[str, int]:
        last: dict[str, int] = {}
        for index, step in enumerate(self.steps):
            for answer in _graded_answer_word_ids(step):
                last[answer] = index
        return last

    def _graded_step_count(self) -> int:
        return sum(1 for step in self.steps if _is_graded_exercise_step(step))

    def _is_word_in_cooldown(self, word: str) -> bool:
        until = self._requiz_blocked_until.get(word, 0)
        if self._graded_step_count() < until:
            return True
        until = self._phrase_component_cooldown_until.get(word, 0)
        return self._graded_step_count() < until

    def _prior_stone_only_words(self) -> set[str]:
        subsets = UNIT_STONE_WORD_SUBSETS.get(self.unit["id"])
        if not subsets or self.stone <= 1:
            return set()
        current = set(subsets[self.stone - 1]) if self.stone <= len(subsets) else set()
        prior: set[str] = set()
        for index in range(self.stone - 1):
            if index < len(subsets):
                prior.update(subsets[index])
        return prior - current - PHRASE_IDS

    def _prior_stone_review_share(self) -> float:
        prior_only = self._prior_stone_only_words()
        if not prior_only:
            return 0.0
        graded = [s for s in self.steps if _is_graded_exercise_step(s)]
        if not graded:
            return 0.0
        prior_hits = sum(
            1
            for step in graded
            if prior_only.intersection(_graded_step_answer_tokens(step))
        )
        return prior_hits / len(graded)

    def _warmup_word_pool(self) -> list[str]:
        subsets = UNIT_STONE_WORD_SUBSETS.get(self.unit["id"])
        pool_words: list[str] = []
        if self.stone >= 2 and subsets:
            for index in range(min(self.stone - 1, len(subsets))):
                pool_words.extend(w for w in subsets[index] if w not in PHRASE_IDS)
        else:
            pool_words = sorted(
                w
                for w in getattr(self, "_lesson_start_taught", set())
                if w in getattr(self, "_lesson_start_introduced", set())
            )
        taught = [
            w
            for w in pool_words
            if w in self.state.taught_set
            and w in self._introduced_pool()
            and w not in PHRASE_IDS
        ]
        return list(dict.fromkeys(taught))

    def _finalize_answer_spacing(self) -> None:
        min_gap = repetition_rule(self.stone, "min_answer_gap")
        density_window = repetition_rule(self.stone, "density_window")
        density_max = repetition_rule(self.stone, "density_max_in_window")
        steps = enforce_min_answer_gap(self.steps, min_gap=min_gap)
        steps = enforce_max_answer_density(steps, density_window, density_max)
        steps = enforce_no_adjacent_same_graded_answer(steps, self.pool)
        self.steps = steps

    def _convert_recognition_to_context(self) -> None:
        if self.stone != 3:
            return
        cap = STONE_RECOGNITION_SHARE_CAP.get(3, 0.58)
        for _ in range(8):
            if self._recognition_share() <= cap:
                break
            swapped = False
            for index in range(len(self.steps) - 1, -1, -1):
                step = self.steps[index]
                if step.get("kind") not in RECOGNITION_KINDS:
                    continue
                word = step.get("answerWordId")
                if word and word in self.fill_by_word and word in self.introduced_in_lesson:
                    self.steps[index] = fill_slot_step(self.fill_by_word[word])
                    swapped = True
                    break
            if not swapped:
                break

    def _recent_graded_answers(
        self, limit: int | None = None
    ) -> set[str]:
        if limit is None:
            limit = repetition_rule(self.stone, "recent_answer_exclusion")
        recent: list[str] = []
        for step in reversed(self.steps):
            for answer in _step_graded_answer_ids(step):
                if step.get("kind") in QUIZ_KINDS or step.get("kind") == "matchPairs":
                    recent.append(answer)
                    if len(recent) >= limit:
                        return set(recent)
        return set(recent)

    def _eligible_quiz_words(self) -> list[str]:
        pool = self._introduced_pool()
        subset = self._stone_subset_vocab() if self.stone <= 2 else []

        # Stone 1 introduces a new unit — never quiz prior-unit vocabulary as
        # the correct answer. Distractors may still draw from earlier units.
        if self.stone == 1 and subset:
            return [
                w
                for w in subset
                if w in self.state.taught_set
                and w in pool
                and w in self.introduced_in_lesson
                and w not in PHRASE_IDS
            ]

        def quizable(word: str) -> bool:
            return (
                word in self.state.introduced_words
                or word in self.introduced_in_lesson
            )

        taught = [
            w
            for w in self.unit["words"]
            if w in self.state.taught_set
            and w in pool
            and w not in PHRASE_IDS
            and quizable(w)
        ]
        if subset:
            taught = list(
                dict.fromkeys(
                    [
                        w
                        for w in subset
                        if w in self.state.taught_set
                        and w in pool
                        and quizable(w)
                    ]
                    + taught
                )
            )
        if len(taught) < 2:
            taught = [
                w
                for w in self.unit["words"]
                if w in self.state.taught_set and w in pool and quizable(w)
            ]
        if self.stone > 1 and len(taught) < 3:
            extras = [
                w
                for w in self.state.prior_pool
                if w in pool
                and w not in PHRASE_IDS
                and w not in taught
                and w in self.state.introduced_words
            ]
            taught = taught + extras
        elif self.stone > 1:
            taught = [
                w
                for w in taught
                if w in self.unit["words"] or w in self.state.introduced_words
            ]
        return taught

    def _pick_least_used_word(self, candidates: list[str]) -> str | None:
        if not candidates:
            return None
        self._slot += 1
        tie_seed = self.unit["sortOrder"] + self.stone + self._slot
        last_indices = self._answer_last_indices()

        def sort_key(word: str) -> tuple[int, int, int]:
            return (
                self._answer_counts.get(word, 0),
                last_indices.get(word, -1),
                (tie_seed + sum(ord(c) for c in word)) % 997,
            )

        return min(candidates, key=sort_key)

    def _record_answer_use(self, step: dict) -> None:
        for answer in _graded_answer_word_ids(step):
            self._answer_counts[answer] += 1

    def _pick_match_pair_words(
        self, count: int, eligible: list[str] | None = None
    ) -> list[str]:
        """Pick match-board words biased toward least-used eligible vocabulary."""
        if eligible is None:
            eligible = self.match_pair_eligible()
        if len(eligible) < 2:
            return []
        count = min(max(count, 2), len(eligible))
        self._slot += 1
        tie_seed = self.unit["sortOrder"] + self.stone + self._slot + len(self.steps)
        last_indices = self._answer_last_indices()

        def sort_key(word: str) -> tuple[int, int, int]:
            return (
                self._answer_counts.get(word, 0),
                last_indices.get(word, -1),
                (tie_seed + sum(ord(c) for c in word)) % 997,
            )

        ordered = sorted(dict.fromkeys(eligible), key=sort_key)
        return ordered[:count]

    def _word_new_this_lesson(self, word: str) -> bool:
        """True when the word is first taught or quizzed in the current lesson."""
        if word in self.introduced_in_lesson:
            return True
        lesson_start_taught = getattr(self, "_lesson_start_taught", set())
        return word in self.state.taught_set and word not in lesson_start_taught

    def _mark_phrase_fill_emitted(self, step: dict) -> None:
        if step.get("kind") != "fillSlot":
            return
        phrase_id = step.get("wordId")
        answer = step.get("answerWordId")
        if phrase_id in PHRASE_IDS and answer:
            self.state.phrase_fill_emitted.add((self.unit["id"], answer))

    def _make_room_for_step(self, slots_needed: int = 1) -> bool:
        """Drop trailing review pads until `slots_needed` steps can fit."""
        limit = self._step_limit()
        needed = max(1, slots_needed)
        droppable = {
            "watchChoose",
            "translationChoose",
            "wordPickVideo",
            "matchPairs",
            "fillSlot",
        }
        while len(self.steps) + needed > limit and self.steps:
            if self.steps[-1].get("kind") in droppable:
                self.steps.pop()
            else:
                return False
        return len(self.steps) + needed <= limit

    def _append_phrase_context_fill(self, word: str) -> bool:
        unit_id = self.unit["id"]
        key = (unit_id, word)
        if key in self.state.phrase_fill_emitted:
            return False
        if not self._word_new_this_lesson(word):
            return False
        entry = self.fill_by_word.get(word)
        if not entry or not entry.get("wordId"):
            return False
        phrase_id = entry.get("wordId")
        if phrase_id and self._phrase_video_exercise_used(phrase_id):
            return False
        if not self._make_room_for_step():
            return False
        self.append(fill_slot_step(entry))
        return True

    def _append_phrase_context_sign_sequence(self, word: str) -> bool:
        unit_id = self.unit["id"]
        key = (unit_id, word)
        if key in self.state.phrase_fill_emitted:
            return False
        if not self._word_new_this_lesson(word):
            return False
        phrase_id = PHRASE_CONTEXT_SIGN_SEQUENCES.get(unit_id, {}).get(word)
        if not phrase_id:
            return False
        if self._phrase_video_exercise_used(phrase_id):
            return False
        components = sign_sequence_components(phrase_id)
        if len(components) < 2:
            return False
        if not self._make_room_for_step():
            return False
        for component in components:
            if component not in self.state.taught_set:
                self.register_taught_word(component)
        step = sign_sequence_step(phrase_id, components, self.pool)
        step["phrasePreview"] = True
        self.append(step)
        self.state.phrase_fill_emitted.add(key)
        return True

    def _inject_phrase_context_fills(self) -> None:
        """Emit phrase context exercises (fillSlot or signSequence) on first teach."""
        unit_id = self.unit["id"]
        fill_specs = PHRASE_FILL_SLOTS.get(unit_id, {})
        sequence_specs = PHRASE_CONTEXT_SIGN_SEQUENCES.get(unit_id, {})
        if not fill_specs and not sequence_specs:
            return
        existing_answers = {
            step.get("answerWordId")
            for step in self.steps
            if step.get("kind") == "fillSlot"
        }
        for word in fill_specs:
            if word in existing_answers:
                continue
            if self._append_phrase_context_fill(word):
                existing_answers.add(word)
        for word in sequence_specs:
            self._append_phrase_context_sign_sequence(word)

    def append_fill_slot(self) -> bool:
        for word in self.unit["words"]:
            if (
                word in self.fill_by_word
                and word in self.state.taught_set
                and word in self.introduced_in_lesson
            ):
                self.append(fill_slot_step(self.fill_by_word[word]))
                return True
        return False

    def append_match_pairs(self, pair_count: int | None = None) -> bool:
        eligible = self.match_pair_eligible()
        if len(eligible) < 2:
            return False
        count = pair_count
        if count is None:
            if self.stone >= 3:
                count = min(3, max(2, len(eligible) // 2))
            else:
                count = 2 if self.stone <= 2 else min(4, max(2, len(eligible) // 2))
        count = min(count, len(eligible))
        pairs = self._pick_match_pair_words(count, eligible)
        pairs = [w for w in pairs if w in eligible]
        if len(pairs) < 2:
            return False
        self.append(match_pairs_step(pairs, STEP_PROMPTS["matchPairs"]))
        return True

    def pad_quizzes(self, kinds: list[str], target: int = MIN_MODULE_STEPS) -> None:
        kind_cycle = kinds
        while len(self.steps) < target:
            word = self.next_taught_word()
            if word is None:
                break
            kind = kind_cycle[len(self.steps) % len(kind_cycle)]
            if kind == "fillSlot" and word not in self.fill_by_word:
                kind = "watchChoose"
            if kind == "fillSlot":
                self.append(fill_slot_step(self.fill_by_word[word]))
            elif kind == "wordPickVideo":
                self.append(word_pick_video_step(word, self.pool))
            elif kind == "translationChoose":
                choices = 3 if len(self.steps) % 2 == 0 else 2
                self.append(translation_choose_step(word, self.pool, choice_count=choices))
            elif kind == "watchChoose":
                count = 3 if len(self.steps) % 3 == 0 else 2
                self.append(watch_choose_step(word, self.pool, choice_count=count))
            elif kind == "matchPairs":
                if not self.append_match_pairs():
                    self.append(watch_choose_step(word, self.pool, choice_count=2))
            else:
                self.append(watch_choose_step(word, self.pool, choice_count=2))

    def fill_untaught_vocab(self, reserve: int = 4) -> None:
        """Introduce remaining stone-subset words before quizzes consume the step budget."""
        words = self.untaught_words()
        phrase_ids = (
            stone_phrase_ids(self.unit["id"], self.stone) if self.stone >= 3 else []
        )
        priority: set[str] = set()
        for phrase_id in phrase_ids:
            priority.update(sign_sequence_components(phrase_id))
        words.sort(key=lambda w: (0 if w in priority else 1, w))
        for word in words:
            if word in PHRASE_IDS:
                continue
            if len(self.steps) >= self._step_limit() - reserve:
                break
            self.append_teach_block(word)

    def finish(self) -> list[dict]:
        self._flush_pending_intro_batch()
        limit = self._step_limit()
        lesson_introduced = getattr(self, "_lesson_start_introduced", set())
        unit_words = set(self.unit["words"])
        steps = _trim_to_limit(self.steps, limit)
        steps = enforce_variety(
            steps,
            lesson_introduced,
            unit_words=unit_words,
        )
        steps = enforce_answer_spread(steps)
        steps = enforce_no_adjacent_new_intros(
            steps,
            unit_words,
            getattr(self, "_lesson_start_introduced", set()),
            self.pool,
        )
        steps = anchor_teach_confirm_pairs(steps)
        steps = enforce_no_adjacent_same_graded_answer(steps, self.pool)
        steps = enforce_max_teach_confirm_pairs(
            steps, self.pool, max_pairs=self._max_teach_confirm_pairs()
        )
        steps = dedupe_phrase_video_exercises(steps)
        steps = separate_adjacent_phrase_video_exercises(steps)
        steps = _trim_to_limit(steps, limit)
        steps = enforce_step_pacing(
            steps,
            self.pool,
            self.fill_by_word,
            lesson_introduced,
            unit_words,
        )
        self.steps = steps
        self._ensure_min_unique_answer_words()
        steps = self.steps
        steps = _trim_to_limit(steps, limit)
        steps = ensure_intro_before_quiz_steps(
            steps,
            getattr(self, "_lesson_start_introduced", set()),
            self.pool,
        )
        steps = _trim_to_limit(steps, limit)
        try:
            assert_intro_before_quiz(
                steps,
                getattr(self, "_lesson_start_introduced", set()),
                unit_words,
            )
        except ValueError:
            pass
        steps = dedupe_teach_steps_per_word(steps)
        steps = dedupe_phrase_video_exercises(steps)
        steps = separate_adjacent_phrase_video_exercises(steps)
        steps = _trim_to_limit(steps, limit)
        self.steps = steps
        try:
            validate_lesson(
                self.steps,
                self.state.taught_set,
                getattr(self, "_lesson_start_introduced", set()),
            )
        except ValueError:
            pass
        self._ensure_stone_exercise_mix()
        self._top_up_to_min_steps()
        self._ensure_subset_words_answered()
        self._ensure_min_unique_answer_words()
        self.steps = _trim_to_limit(self.steps, limit)
        while (
            self.steps
            and self.steps[-1].get("kind") == "teach"
            and len(self.steps) > STONE_MIN_STEPS.get(self.stone, MIN_MODULE_STEPS)
        ):
            self.steps.pop()
        if self.stone == 1:
            self._cap_stone1_watch_choose_share()
        self._ensure_lesson_endings()
        self.steps = anchor_teach_confirm_pairs(self.steps)
        self.steps = enforce_max_teach_confirm_pairs(
            self.steps, self.pool, max_pairs=self._max_teach_confirm_pairs()
        )
        self.steps = dedupe_phrase_video_exercises(self.steps)
        self.steps = separate_adjacent_phrase_video_exercises(self.steps)
        self._top_up_to_min_steps()
        self.steps = _trim_to_limit(self.steps, limit)
        self._ensure_translation_choose_min()
        self._ensure_min_match_pairs()
        self._ensure_context_steps_min()
        self._inject_phrase_context_fills()
        if self.stone == 3:
            self._convert_recognition_to_context()
        self.steps = separate_adjacent_match_pairs(self.steps, self.pool)
        self._ensure_asl_tip()
        self._ensure_your_turn()
        self._ensure_lesson_endings()
        self._rebalance_graded_mix()
        self._rebalance_graded_mix()
        self.steps = _trim_to_limit(self.steps, limit)
        self._finalize_answer_spacing()
        self._cap_answer_repetition()
        self._finalize_answer_spacing()
        self._cap_answer_repetition()
        self.steps = _trim_to_limit(self.steps, limit)
        self.steps = anchor_phrase_preview_sign_sequences(self.steps, self.unit["id"])
        self.steps = enforce_one_recognition_modality(
            self.steps, self.pool, stone=self.stone
        )
        if self.stone <= 2:
            self.steps = cap_your_turn_steps(self.steps, stone=self.stone, max_count=1)
        return self.steps

    def _graded_kinds_set(self) -> frozenset[str]:
        return QUIZ_KINDS | {"matchPairs", "fillSlot", "signSequence", "phraseSlot"}

    def _recognition_share(self) -> float:
        graded = [s for s in self.steps if s.get("kind") in self._graded_kinds_set()]
        if not graded:
            return 0.0
        recognition = sum(1 for s in graded if s.get("kind") in RECOGNITION_KINDS)
        return recognition / len(graded)

    def _is_teach_adjacent_confirm(self, index: int) -> bool:
        if index <= 0 or index >= len(self.steps):
            return False
        prev_kind = self.steps[index - 1].get("kind")
        if prev_kind != "teach":
            return False
        curr = self.steps[index]
        if curr.get("kind") not in INTRO_CONFIRM_KINDS:
            return False
        teach_word = self.steps[index - 1].get("wordId")
        answer = curr.get("answerWordId")
        return bool(teach_word and answer == teach_word)

    def _convert_recognition_step(self, index: int) -> bool:
        """Swap one recognition step for match, translation, or fill when over cap."""
        step = self.steps[index]
        word = step.get("answerWordId")
        if not word or step.get("kind") not in RECOGNITION_KINDS:
            return False
        if self._is_teach_adjacent_confirm(index):
            return False
        prior = self.steps[:index]
        if len(self.match_pair_eligible()) >= MIN_MATCH_PAIRS_ELIGIBLE:
            pairs = self.match_pair_eligible()
            count = min(3, len(pairs)) if self.stone >= 3 else 2
            pair_ids = self._pick_match_pair_words(count, pairs)
            candidate = match_pairs_step(pair_ids, STEP_PROMPTS["matchPairs"])
            if _pacing_ok(prior, candidate):
                self.steps[index] = candidate
                return True
        for fill_word, entry in PHRASE_FILL_SLOTS.get(self.unit["id"], {}).items():
            if fill_word not in self.introduced_in_lesson:
                continue
            candidate = fill_slot_step(entry)
            if _pacing_ok(prior, candidate):
                self.steps[index] = candidate
                return True
        if self.stone == 1:
            candidate = stone1_translation_choose_step(word, self.pool)
        else:
            choice_count = 4 if self.stone >= 3 else 2
            candidate = translation_choose_step(
                word, self.pool, choice_count=choice_count
            )
        if _pacing_ok(prior, candidate):
            self.steps[index] = candidate
            return True
        if self._recognition_share() > STONE_RECOGNITION_SHARE_CAP.get(self.stone, 0.65) + 0.02:
            self.steps[index] = candidate
            return True
        return False

    def _rebalance_recognition_ratio(self) -> None:
        """Nudge watchChoose:wordPickVideo toward stone targets within recognition."""
        watch_target, pick_target = STONE_WATCH_TO_WORD_PICK_TARGET.get(
            self.stone, (0.50, 0.50)
        )
        for _ in range(32):
            recognition = [
                (i, self.steps[i])
                for i, s in enumerate(self.steps)
                if s.get("kind") in RECOGNITION_KINDS
            ]
            if len(recognition) < 2:
                break
            watch_n = sum(1 for _, s in recognition if s.get("kind") == "watchChoose")
            pick_n = len(recognition) - watch_n
            total = len(recognition)
            watch_share = watch_n / total
            pick_share = pick_n / total
            if (
                abs(watch_share - watch_target) <= 0.08
                and abs(pick_share - pick_target) <= 0.08
            ):
                break
            if watch_share > watch_target + 0.05:
                excess_kind = "watchChoose"
                target_kind = "wordPickVideo"
            elif pick_share > pick_target + 0.05:
                excess_kind = "wordPickVideo"
                target_kind = "watchChoose"
            else:
                break
            swapped = False
            for index, step in reversed(recognition):
                if step.get("kind") != excess_kind:
                    continue
                if self._is_teach_adjacent_confirm(index):
                    continue
                word = step.get("answerWordId")
                if not word:
                    continue
                if target_kind == "wordPickVideo":
                    candidate = word_pick_video_step(word, self.pool)
                else:
                    choice_count = 4 if self.stone >= 3 else 2
                    candidate = watch_choose_step(
                        word, self.pool, choice_count=choice_count
                    )
                prior = self.steps[:index]
                if _pacing_ok(prior, candidate):
                    self.steps[index] = candidate
                    swapped = True
                    break
            if not swapped:
                break

    def _rebalance_graded_mix(self) -> None:
        """Trim recognition share and rebalance watchChoose vs wordPickVideo."""
        cap = STONE_RECOGNITION_SHARE_CAP.get(self.stone, 0.65)
        for _ in range(96):
            if self._recognition_share() <= cap + 0.01:
                break
            swapped = False
            for index in range(len(self.steps) - 1, -1, -1):
                if self.steps[index].get("kind") not in RECOGNITION_KINDS:
                    continue
                if self._convert_recognition_step(index):
                    swapped = True
                    break
            if not swapped:
                break
        while self._recognition_share() > cap + 0.01:
            converted = False
            for index in range(len(self.steps) - 1, -1, -1):
                if self.steps[index].get("kind") not in RECOGNITION_KINDS:
                    continue
                if self._is_teach_adjacent_confirm(index):
                    continue
                word = self.steps[index].get("answerWordId")
                if not word:
                    continue
                pairs = self.match_pair_eligible()
                if len(pairs) >= MIN_MATCH_PAIRS_ELIGIBLE:
                    count = min(3, len(pairs))
                    pair_ids = self._pick_match_pair_words(count, pairs)
                    self.steps[index] = match_pairs_step(
                        pair_ids, STEP_PROMPTS["matchPairs"]
                    )
                elif self.stone == 1:
                    self.steps[index] = stone1_translation_choose_step(word, self.pool)
                else:
                    choice_count = 4 if self.stone >= 3 else 2
                    self.steps[index] = translation_choose_step(
                        word, self.pool, choice_count=choice_count
                    )
                converted = True
                break
            if not converted:
                break
        self._rebalance_recognition_ratio()

    def _ensure_translation_choose_min(self) -> None:
        """Guarantee minimum translationChoose steps per stone."""
        minimum = STONE_MIN_TRANSLATION_CHOOSE.get(self.stone, 0)
        if minimum <= 0:
            return
        if self.stone == 1:
            self._ensure_stone1_translation_choose_min()
            return

        def translation_choose_count() -> int:
            return sum(
                1 for step in self.steps if step.get("kind") == "translationChoose"
            )

        convertible_kinds = ("watchChoose", "wordPickVideo")
        for index, step in enumerate(list(self.steps)):
            if translation_choose_count() >= minimum:
                return
            if step.get("kind") not in convertible_kinds:
                continue
            if self._is_teach_adjacent_confirm(index):
                continue
            word = step.get("answerWordId")
            if not word:
                continue
            choice_count = 4 if self.stone >= 3 else 2
            self.steps[index] = translation_choose_step(
                word, self.pool, choice_count=choice_count
            )

        stall = 0
        while (
            translation_choose_count() < minimum
            and len(self.steps) < self._step_limit()
        ):
            before = len(self.steps)
            word = self._pick_review_word() or self._pick_padding_word()
            if not word:
                break
            choice_count = 4 if self.stone >= 3 else 2
            self._append_quiz(
                translation_choose_step(word, self.pool, choice_count=choice_count),
                _spacing_guard=False,
            )
            if len(self.steps) == before:
                stall += 1
                if stall >= 8:
                    break
            else:
                stall = 0

    def _ensure_min_match_pairs(self) -> None:
        """Guarantee at least one matchPairs step when eligible."""
        minimum = STONE_MIN_MATCH_PAIRS.get(self.stone, 0)
        if minimum <= 0:
            return
        if sum(1 for s in self.steps if s.get("kind") == "matchPairs") >= minimum:
            return
        if len(self.match_pair_eligible()) < MIN_MATCH_PAIRS_ELIGIBLE:
            return
        if len(self.steps) >= self._step_limit():
            if not self._make_room_for_step(slots_needed=1):
                return
        self.append_match_pairs()

    def _context_step_count(self) -> int:
        return sum(1 for s in self.steps if s.get("kind") in CONTEXT_STEP_KINDS)

    def _unit_has_context_data(self) -> bool:
        unit_id = self.unit["id"]
        if PHRASE_FILL_SLOTS.get(unit_id) or PHRASE_CONTEXT_SIGN_SEQUENCES.get(unit_id):
            return True
        if unit_id in PHRASE_SEQUENCE_UNITS:
            return any(
                w in PHRASE_IDS
                for w in self.unit["words"]
            )
        return False

    def _ensure_context_steps_min(self) -> None:
        """Inject phrase/fill context steps on stones 3–4 when data exists."""
        minimum = STONE_MIN_CONTEXT_STEPS.get(self.stone, 0)
        if minimum <= 0:
            return
        if not self._unit_has_context_data():
            return
        stall = 0
        while (
            self._context_step_count() < minimum
            and len(self.steps) < self._step_limit()
        ):
            before = self._context_step_count()
            if self.stone >= 3:
                _inject_phrase_slot_reviews(self)
            for word in PHRASE_FILL_SLOTS.get(self.unit["id"], {}):
                if self._context_step_count() >= minimum:
                    break
                self._append_phrase_context_fill(word)
            for word in PHRASE_CONTEXT_SIGN_SEQUENCES.get(self.unit["id"], {}):
                if self._context_step_count() >= minimum:
                    break
                self._append_phrase_context_sign_sequence(word)
            if self.unit["id"] in PHRASE_SEQUENCE_UNITS:
                for phrase_id in self.unit["words"]:
                    if phrase_id not in PHRASE_IDS:
                        continue
                    if self._context_step_count() >= minimum:
                        break
                    if phrase_id in self.state.sequenced_phrases:
                        _append_phrase_slot_review(self, phrase_id)
                    elif len(self.steps) < self._step_limit() - 2:
                        _append_phrase_block(self, phrase_id)
            if self._context_step_count() == before:
                stall += 1
                if stall >= 4:
                    break
            else:
                stall = 0

    def _ensure_lesson_endings(self) -> None:
        """Avoid ending on yourTurn or teach; prefer a win beat at the close."""
        if not self.steps:
            return
        min_steps = STONE_MIN_STEPS.get(self.stone, MIN_MODULE_STEPS)
        if self.stone == 3:
            for _ in range(8):
                last = self.steps[-1]
                kind = last.get("kind")
                if kind == "matchPairs":
                    break
                if kind == "teach" and len(self.steps) > min_steps:
                    self.steps.pop()
                    continue
                swap_index = None
                for index in range(len(self.steps) - 2, max(len(self.steps) - 8, -1), -1):
                    if self.steps[index].get("kind") == "matchPairs":
                        swap_index = index
                        break
                if swap_index is not None:
                    self.steps[swap_index], self.steps[-1] = (
                        self.steps[-1],
                        self.steps[swap_index],
                    )
                    break
                if kind in {"translationChoose", "wordPickVideo", "watchChoose"} and len(
                    self.steps
                ) > min_steps:
                    self.steps.pop()
                    continue
                break
        for _ in range(8):
            last = self.steps[-1]
            kind = last.get("kind")
            if kind == "teach" and len(self.steps) > STONE_MIN_STEPS.get(
                self.stone, MIN_MODULE_STEPS
            ):
                self.steps.pop()
                continue
            if kind != "yourTurn" or len(self.steps) < 2:
                break
            swap_index = None
            for index in range(len(self.steps) - 2, max(len(self.steps) - 6, -1), -1):
                k = self.steps[index].get("kind")
                if k in {"matchPairs", "watchChoose", "wordPickVideo", "translationChoose"}:
                    swap_index = index
                    break
            if swap_index is None:
                break
            self.steps[swap_index], self.steps[-1] = (
                self.steps[-1],
                self.steps[swap_index],
            )
            break

    def _midlesson_your_turn_candidates(
        self, before_index: int, used_your_turn: set[str]
    ) -> list[str]:
        """Words already answered at least once before the lesson midpoint."""
        counts: Counter[str] = Counter()
        for step in self.steps[:before_index]:
            for word_id in _graded_answer_word_ids(step):
                if word_id and word_id not in PHRASE_IDS:
                    counts[word_id] += 1
        return [
            word_id
            for word_id, count in counts.items()
            if count >= 1 and word_id not in used_your_turn
        ]

    def _midlesson_your_turn_insert_index(self, word: str) -> int | None:
        """Place Your Turn near the midpoint, after the word's first graded answer."""
        step_count = len(self.steps)
        if step_count < 4:
            return None
        target = step_count // 2
        first_answer_idx: int | None = None
        for index, step in enumerate(self.steps):
            if word in _graded_answer_word_ids(step):
                first_answer_idx = index
                break
        if first_answer_idx is None:
            return None
        insert_at = max(first_answer_idx + 1, target)
        insert_at = min(insert_at, max(step_count - 2, first_answer_idx + 1))
        if insert_at > 0 and self.steps[insert_at - 1].get("kind") == "teach":
            insert_at = min(insert_at + 1, step_count)
        return insert_at

    def _midlesson_your_turn_placed_count(self) -> int:
        """Count Your Turn steps near the midpoint with a prior graded answer."""
        step_count = len(self.steps)
        if step_count < 4:
            return 0
        target = step_count // 2
        tolerance = max(3, step_count // 4)
        placed = 0
        for index, step in enumerate(self.steps):
            if step.get("kind") != "yourTurn":
                continue
            word_id = step.get("wordId")
            if not word_id:
                continue
            answered_before = any(
                word_id in _graded_answer_word_ids(prior)
                for prior in self.steps[:index]
            )
            if answered_before and abs(index - target) <= tolerance:
                placed += 1
        return placed

    def _ensure_midlesson_your_turn(self) -> None:
        """One mid-lesson Your Turn on stones 1–3, after the sign was answered once."""
        needed = STONE_MID_YOUR_TURN.get(self.stone, 0)
        if needed == 0:
            return
        while self._midlesson_your_turn_placed_count() < needed:
            if len(self.steps) >= self._step_limit():
                if not self._make_room_for_step(slots_needed=1):
                    return
            used_your_turn = {
                step.get("wordId")
                for step in self.steps
                if step.get("kind") == "yourTurn" and step.get("wordId")
            }
            target = len(self.steps) // 2
            candidates = self._midlesson_your_turn_candidates(target, used_your_turn)
            if self.stone == 2:
                subset = set(self._stone_subset_vocab())
                subset_candidates = [w for w in candidates if w in subset]
                if subset_candidates:
                    candidates = subset_candidates
            word = None
            if self.last_taught_word and self.last_taught_word in candidates:
                if self.stone != 2 or self.last_taught_word in self._stone_subset_vocab():
                    word = self.last_taught_word
            if not word:
                word = self._pick_least_used_word(candidates)
            if not word:
                return
            insert_at = self._midlesson_your_turn_insert_index(word)
            if insert_at is None:
                return
            self.steps.insert(insert_at, your_turn_step(word))
            self.last_kind = "yourTurn"

    def _ensure_your_turn(self) -> None:
        """Guarantee record-yourself beats when the arc skips them."""
        self._ensure_midlesson_your_turn()
        min_turns = STONE_MIN_YOUR_TURN.get(self.stone, 0)
        if min_turns == 0:
            return
        while sum(1 for step in self.steps if step.get("kind") == "yourTurn") < min_turns:
            if len(self.steps) >= self._step_limit():
                if not self._make_room_for_step(slots_needed=1):
                    return
            used_your_turn = {
                step.get("wordId")
                for step in self.steps
                if step.get("kind") == "yourTurn" and step.get("wordId")
            }
            candidates = [
                w
                for w in self.taught_words()
                if w not in used_your_turn
            ]
            if self.stone >= 3:
                phrase_candidates = [w for w in candidates if w in PHRASE_IDS]
                if phrase_candidates:
                    candidates = phrase_candidates
                else:
                    candidates = [w for w in candidates if w not in PHRASE_IDS]
            else:
                candidates = [w for w in candidates if w not in PHRASE_IDS]
            if self.stone == 2:
                subset = set(self._stone_subset_vocab())
                subset_candidates = [w for w in candidates if w in subset]
                if subset_candidates:
                    candidates = subset_candidates
            word = None
            if self.last_taught_word and self.last_taught_word in candidates:
                if self.stone != 2 or self.last_taught_word in self._stone_subset_vocab():
                    word = self.last_taught_word
            if not word:
                word = self._pick_least_used_word(candidates)
            if not word:
                word = self._pick_least_used_word(
                    [w for w in self.taught_words() if w not in PHRASE_IDS]
                )
            if not word:
                return
            insert_at = max(len(self.steps) - 3, 1)
            if insert_at >= len(self.steps):
                insert_at = max(len(self.steps) - 1, 0)
            if insert_at > 0 and self.steps[insert_at - 1].get("kind") == "teach":
                insert_at = min(insert_at + 1, len(self.steps))
            self.steps.insert(insert_at, your_turn_step(word))
            self.last_kind = "yourTurn"

    def _ensure_asl_tip(self) -> None:
        """Every stone includes one ASL tip when there is room in the step budget."""
        if any(step.get("kind") == "aslTip" for step in self.steps):
            return
        if self.stone == 1 and len(self.introduced_in_lesson) < 2:
            return
        if len(self.steps) >= self._step_limit():
            if not self._make_room_for_step(slots_needed=1):
                return
        tip, next_cursor = alloc_asl_tip(
            self.state.asl_tip_used_ids,
            self.state.asl_tip_cursor,
        )
        self.state.asl_tip_cursor = next_cursor
        insert_at = max(len(self.steps) - 1, 0)
        if insert_at > 0 and self.steps[insert_at - 1].get("kind") == "teach":
            insert_at = len(self.steps)
        self.steps.insert(
            insert_at,
            asl_tip_step(tip),
        )
        self.last_kind = "aslTip"

    def _ensure_stone1_translation_choose_min(self) -> None:
        """Guarantee two Pick the meaning checks even after quiz-kind coercion."""

        def translation_choose_count() -> int:
            return sum(
                1 for step in self.steps if step.get("kind") == "translationChoose"
            )

        def replace_index_with_translation_choose(index: int) -> bool:
            word = self.steps[index].get("answerWordId")
            if not word:
                return False
            self.steps[index] = stone1_translation_choose_step(word, self.pool)
            return True

        convertible_kinds = ("watchChoose", "wordPickVideo")
        for pass_after_teach in (False, True):
            for index, step in enumerate(self.steps):
                if translation_choose_count() >= STONE1_MIN_TRANSLATION_CHOOSE:
                    return
                if step.get("kind") not in convertible_kinds:
                    continue
                if (
                    not pass_after_teach
                    and index > 0
                    and self.steps[index - 1].get("kind") == "teach"
                ):
                    continue
                replace_index_with_translation_choose(index)

        stall = 0
        while (
            translation_choose_count() < STONE1_MIN_TRANSLATION_CHOOSE
            and len(self.steps) < self._step_limit()
        ):
            before = len(self.steps)
            word = self._pick_review_word() or self._pick_padding_word()
            if not word:
                break
            self._append_quiz(
                stone1_translation_choose_step(word, self.pool),
                _spacing_guard=False,
            )
            if len(self.steps) == before:
                stall += 1
                if stall >= 8:
                    break
            else:
                stall = 0

    def _cap_stone1_watch_choose_share(self) -> None:
        """Keep stone 1 watchChoose under the 40% graded-step cap."""
        if self.stone != 1:
            return
        graded_kinds = QUIZ_KINDS | {"matchPairs", "fillSlot", "signSequence", "phraseSlot"}
        for _ in range(24):
            graded_idxs = [
                index
                for index, step in enumerate(self.steps)
                if step.get("kind") in graded_kinds
            ]
            if not graded_idxs:
                break
            watch_count = sum(
                1 for index in graded_idxs if self.steps[index].get("kind") == "watchChoose"
            )
            if watch_count / len(graded_idxs) < 0.40:
                break
            swapped = False
            for index in graded_idxs:
                if self.steps[index].get("kind") != "watchChoose":
                    continue
                if index > 0 and self.steps[index - 1].get("kind") == "teach":
                    continue
                word = self.steps[index].get("answerWordId")
                if not word:
                    continue
                self.steps[index] = word_pick_video_step(word, self.pool)
                swapped = True
                break
            if not swapped:
                break

    def _ensure_stone_exercise_mix(self) -> None:
        """Guarantee each stone includes required graded exercise variety."""
        limit = self._step_limit()
        unit_has_fill = bool(PHRASE_FILL_SLOTS.get(self.unit["id"]))

        if unit_has_fill and "fillSlot" not in {s.get("kind") for s in self.steps}:
            self._inject_phrase_context_fills()

        kinds_present = {step.get("kind") for step in self.steps}

        if (
            "matchPairs" not in kinds_present
            and len(self.match_pair_eligible()) >= MIN_MATCH_PAIRS_ELIGIBLE
            and len(self.steps) < limit
        ):
            self.append_match_pairs()
            kinds_present.add("matchPairs")

        if self.stone == 1:
            if (
                self.unit["id"] in PHRASE_SEQUENCE_UNITS
                and "signSequence" not in kinds_present
            ):
                filmed = [
                    w
                    for w in self.unit["words"]
                    if w in PHRASE_IDS
                ]
                if filmed:
                    phrase_id = min(
                        filmed, key=lambda pid: _phrase_block_step_cost(self, pid)
                    )
                    cost = _phrase_block_step_cost(self, phrase_id)
                    before = len(self.steps)
                    if self._make_room_for_step(slots_needed=cost):
                        _append_phrase_block(self, phrase_id)
                    if len(self.steps) > before:
                        kinds_present.add("signSequence")

            stall = 0
            while (
                sum(1 for step in self.steps if step.get("kind") == "wordPickVideo")
                < STONE1_MIN_WORD_PICK_VIDEO
                and len(self.steps) < limit
            ):
                before = len(self.steps)
                word = self._pick_review_word()
                if not word:
                    break
                self._append_quiz(word_pick_video_step(word, self.pool))
                if len(self.steps) == before:
                    stall += 1
                    if stall >= 8:
                        break
                else:
                    stall = 0

            stall = 0
            while (
                sum(
                    1
                    for step in self.steps
                    if step.get("kind") == "translationChoose"
                )
                < STONE1_MIN_TRANSLATION_CHOOSE
                and len(self.steps) < limit
            ):
                before = len(self.steps)
                word = self._pick_review_word() or self._pick_padding_word()
                if not word:
                    break
                self._append_quiz(stone1_translation_choose_step(word, self.pool))
                if len(self.steps) == before:
                    stall += 1
                    if stall >= 8:
                        break
                else:
                    stall = 0

            if "watchChoose" not in kinds_present and len(self.steps) < limit:
                word = self._pick_review_word()
                if word:
                    self._append_quiz(
                        watch_choose_step(word, self.pool, choice_count=2)
                    )

            self._cap_stone1_watch_choose_share()
            return

        min_kinds = 4
        graded_kinds = kinds_present & (
            QUIZ_KINDS | {"matchPairs", "fillSlot", "signSequence", "phraseSlot"}
        )
        pad_cycle = [
            "wordPickVideo",
            "translationChoose",
            "matchPairs",
            "watchChoose",
        ]
        stall = 0
        while len(graded_kinds) < min_kinds and len(self.steps) < limit - 1:
            before = len(self.steps)
            kind = pad_cycle[len(graded_kinds) % len(pad_cycle)]
            if kind == "fillSlot":
                if not self.append_fill_slot():
                    for word in PHRASE_FILL_SLOTS.get(self.unit["id"], {}):
                        self._append_phrase_context_fill(word)
                    for word in PHRASE_CONTEXT_SIGN_SEQUENCES.get(self.unit["id"], {}):
                        self._append_phrase_context_sign_sequence(word)
            elif kind == "matchPairs":
                self.append_match_pairs()
            else:
                word = self._pick_review_word()
                if not word:
                    break
                if kind == "wordPickVideo":
                    self._append_quiz(word_pick_video_step(word, self.pool))
                elif kind == "translationChoose":
                    choice_count = 4 if self.stone >= 3 else 2
                    self._append_quiz(
                        translation_choose_step(word, self.pool, choice_count=choice_count)
                    )
                else:
                    self._append_quiz(
                        watch_choose_step(word, self.pool, choice_count=2)
                    )
            graded_kinds = {
                step.get("kind")
                for step in self.steps
                if step.get("kind")
                in QUIZ_KINDS | {"matchPairs", "fillSlot", "signSequence", "phraseSlot"}
            }
            if len(self.steps) == before:
                stall += 1
                if stall >= len(pad_cycle):
                    break
            else:
                stall = 0

    def _pick_padding_word(self) -> str | None:
        """Least-used introduced word for length padding (relaxed vs review picker)."""
        pool = [
            w
            for w in self._eligible_quiz_words()
            if w not in PHRASE_IDS
        ]
        if not pool:
            pool = [
                w
                for w in self.unit["words"]
                if w in self._introduced_pool() and w not in PHRASE_IDS
            ]
        if not pool:
            return None
        return self._pick_least_used_word(pool)

    def _top_up_to_min_steps(self) -> None:
        """Append review pads until the stone hits STONE_MIN_STEPS (after trimming)."""
        min_steps = STONE_MIN_STEPS.get(self.stone, MIN_MODULE_STEPS)
        stall = 0
        while len(self.steps) < min_steps:
            if len(self.steps) >= self._step_limit():
                break
            before = len(self.steps)
            if not self._append_review_pad():
                word = self._pick_review_word() or self._pick_padding_word()
                if not word:
                    break
                before_pad = len(self.steps)
                self._append_stone1_recognition_quiz(word)
                if len(self.steps) == before_pad:
                    slot = len(self.steps) + self._slot
                    self._slot += 1
                    pick = slot % 3
                    if pick == 0:
                        self._append_quiz(
                            word_pick_video_step(word, self.pool),
                            _spacing_guard=False,
                        )
                    elif pick == 1:
                        self._append_quiz(
                            watch_choose_step(word, self.pool, choice_count=2),
                            _spacing_guard=False,
                        )
                    else:
                        self._append_quiz(
                            stone1_translation_choose_step(word, self.pool),
                            _spacing_guard=False,
                        )
            if len(self.steps) == before:
                stall += 1
                if stall >= 16:
                    break
            else:
                stall = 0

    def _append_stone1_recognition_quiz(self, word: str) -> None:
        """Four-way recognition rotation on stone 1; stones 2+ use simpler fallback."""
        if self.stone == 1:
            slot = len(self.steps) + self._slot
            self._slot += 1
            pick = slot % 4
            if pick == 0:
                self._append_quiz(word_pick_video_step(word, self.pool))
            elif pick == 1:
                self._append_quiz(stone1_translation_choose_step(word, self.pool))
            elif pick == 2:
                self._append_quiz(word_pick_video_step(word, self.pool))
            else:
                fill_candidates = [
                    w
                    for w in self._eligible_quiz_words()
                    if w in self.fill_by_word and w in self.introduced_in_lesson
                ]
                fill_word = self._pick_least_used_word(fill_candidates) or word
                if fill_word in self.fill_by_word:
                    self.append(fill_slot_step(self.fill_by_word[fill_word]))
                elif len(self.match_pair_eligible()) >= MIN_MATCH_PAIRS_ELIGIBLE:
                    self.append_match_pairs()
                else:
                    self._append_quiz(word_pick_video_step(word, self.pool))
            return
        choice_count = 4 if self.stone >= 3 else 2
        if self.stone <= 2:
            if self.last_kind in WORD_TO_SIGN_KINDS:
                self._append_quiz(
                    watch_choose_step(word, self.pool, choice_count=choice_count)
                )
            else:
                self._append_quiz(word_pick_video_step(word, self.pool))
        else:
            self._append_quiz(
                translation_choose_step(word, self.pool, choice_count=choice_count)
            )

    def compose_from_beats(self, stone: int) -> None:
        """Build a stone lesson from the emotional pacing beat arc."""
        self.stone = stone
        step_limit = self._step_limit()
        self._lesson_start_taught = set(self.state.taught_set)
        self._lesson_start_introduced = set(self.state.introduced_words)
        self.introduced_in_lesson = set()
        self._last_new_intro_word = None
        self._intro_streak = 0
        self._pending_intro_words = []
        self._requiz_blocked_until = {}
        self._phrase_component_cooldown_until = {}
        self._recognition_modality_by_word = {}
        self.last_taught_word: str | None = None
        self._last_phrase_id: str | None = None
        self._last_phrase_components: list[str] = []
        self.new_teaches_in_lesson = 0
        subsets = UNIT_STONE_WORD_SUBSETS.get(self.unit["id"])
        if subsets and 1 <= stone <= len(subsets):
            self.max_new_teaches = len(subsets[stone - 1])
        else:
            unit_words = [w for w in self.unit["words"] if w not in PHRASE_IDS]
            self.max_new_teaches = max(1, math.ceil(len(unit_words) / 3))
        fill_reserves = {1: 4, 2: 8, 3: 6}
        self._fill_untaught_reserve = fill_reserves.get(stone, 6)
        self._slot = 0

        if stone <= 2:
            self._introduce_stone_subset_vocab()

        beats = list(STONE_BEATS.get(stone, STONE_BEATS[1]))
        phrase_queue: list[str] = []
        if self.unit["id"] in PHRASE_SEQUENCE_UNITS and stone >= 1:
            if stone == 1:
                filmed = [
                    w
                    for w in self.unit["words"]
                    if w in PHRASE_IDS
                ]
                if filmed:
                    phrase_queue = [
                        min(filmed, key=lambda pid: _phrase_block_step_cost(self, pid))
                    ]
            else:
                phrase_queue = list(stone_phrase_ids(self.unit["id"], stone))

        reserved_phrase: str | None = phrase_queue[0] if stone == 1 and phrase_queue else None
        if stone == 3:
            phrase_headroom = 4
        else:
            phrase_headroom = (
                min(_phrase_block_step_cost(self, reserved_phrase), 10)
                if reserved_phrase
                else 0
            )
        beat_limit = step_limit - phrase_headroom

        for beat in beats:
            protected_beat = beat in {"aslTip"} or (
                beat == "yourTurn" and stone >= 2
            )
            if not protected_beat and len(self.steps) >= beat_limit:
                continue
            if protected_beat and len(self.steps) >= step_limit:
                continue
            self._apply_beat(beat)
            if (
                phrase_queue
                and beat in PHRASE_SPRINKLE_BEATS
                and reserved_phrase is None
            ):
                phrase_id = phrase_queue.pop(0)
                if len(self.steps) < step_limit - 1:
                    _append_phrase_block(self, phrase_id)

        if reserved_phrase and reserved_phrase not in self.state.sequenced_phrases:
            _append_phrase_block(self, reserved_phrase)
            phrase_queue = [p for p in phrase_queue if p != reserved_phrase]

        if stone < 3:
            if subsets and stone <= len(subsets):
                self.fill_untaught_vocab(reserve=self._fill_untaught_reserve)
            elif stone <= 2:
                self.fill_untaught_vocab(reserve=self._fill_untaught_reserve)

        while phrase_queue and len(self.steps) < step_limit - 2:
            _append_phrase_block(self, phrase_queue.pop(0))
            if phrase_queue and len(self.steps) < step_limit - 2:
                self._append_review_pad()

        self._inject_phrase_context_fills()

        if stone in (2, 3):
            _inject_phrase_slot_reviews(self)
        if stone != 3:
            self._catch_up_untaught()

        pad_target = self._step_limit()
        stall = 0
        while len(self.steps) < pad_target:
            if len(self.steps) >= step_limit:
                break
            before = len(self.steps)
            if not self._append_review_pad():
                word = self._pick_review_word()
                if not word:
                    break
                self._append_stone1_recognition_quiz(word)
            if len(self.steps) == before:
                stall += 1
                if stall >= 5:
                    break
            else:
                stall = 0

        # Coverage and repetition caps run in finish() after beats and padding.

    def _catch_up_untaught(self) -> None:
        if self.stone == 3:
            return
        for word in self.untaught_words():
            if word in PHRASE_IDS:
                continue
            if word in self.state.ever_taught:
                continue
            if len(self.steps) >= self._step_limit() - 2:
                break
            if self._intro_streak >= MAX_BACK_TO_BACK_NEW_INTROS:
                self._flush_pending_intro_batch()
            self.new_teaches_in_lesson += 1
            self.append_teach_block(word)
            if word not in self._unique_graded_answers():
                while (
                    len(self.steps) >= self._step_limit()
                    and not self._make_room_for_step(slots_needed=1)
                ):
                    break
                if len(self.steps) < self._step_limit():
                    slot = len(self.steps)
                    self._append_quiz(self._varied_confirm_quiz(word, slot))

    def _next_untaught_vocab(self) -> str | None:
        for word in self.untaught_words():
            if word in PHRASE_IDS:
                continue
            return word
        return None

    def _pick_review_word(self) -> str | None:
        candidates = self._eligible_quiz_words()
        candidates = [w for w in candidates if not self._is_word_in_cooldown(w)]
        if self.stone == 2 and self._prior_stone_review_share() >= PRIOR_STONE_REVIEW_SHARE_CAP:
            current = set(self._stone_subset_vocab())
            narrowed = [w for w in candidates if w in current]
            if narrowed:
                candidates = narrowed
        recent = self._recent_graded_answers()
        filtered = [w for w in candidates if w not in recent]
        if filtered:
            candidates = filtered
        elif len(candidates) > 1 and recent:
            return None
        blocked = [w for w in candidates if not self._is_word_in_cooldown(w)]
        return self._pick_least_used_word(blocked or candidates)

    def _pick_cross_unit_word(self) -> str | None:
        """A taught word from an earlier unit in the same phase when possible."""
        unit_words = set(self.unit["words"])
        introduced_pool = self._introduced_pool()
        phase = self.unit.get("phaseKey")
        same_phase: list[str] = []
        for prior_unit in getattr(self.state, "ordered_units", []):
            if prior_unit["sortOrder"] >= self.unit["sortOrder"]:
                break
            if phase and prior_unit.get("phaseKey") != phase:
                continue
            for word in prior_unit["words"]:
                if (
                    word not in unit_words
                    and word not in PHRASE_IDS
                    and word in introduced_pool
                    and word in self.state.introduced_words
                    and word not in same_phase
                ):
                    same_phase.append(word)
        candidates = same_phase or [
            w
            for w in self.state.prior_pool
            if w not in unit_words
            and w in introduced_pool
            and w in self.state.introduced_words
            and w not in PHRASE_IDS
        ]
        if not candidates:
            return None
        index = (self.unit["sortOrder"] + self.stone + self._slot) % len(candidates)
        self._slot += 1
        return candidates[index]

    def _append_review_pad(self) -> bool:
        """Length padding that cycles review words and varies the exercise type."""
        word = self._pick_review_word()
        if not word:
            return False
        kinds = STONE_PAD_KIND_WEIGHTS.get(self.stone, STONE_PAD_KIND_WEIGHTS[2])
        kind = kinds[self._slot % len(kinds)]
        if kind == "translationChoose":
            if self.stone == 1:
                self._append_quiz(stone1_translation_choose_step(word, self.pool))
            else:
                choice_count = 4 if self.stone >= 2 else 2
                self._append_quiz(
                    translation_choose_step(word, self.pool, choice_count=choice_count)
                )
        elif kind == "wordPickVideo":
            self._append_quiz(word_pick_video_step(word, self.pool))
        elif kind == "matchPairs":
            if (
                len(self.match_pair_eligible()) >= MIN_MATCH_PAIRS_ELIGIBLE
                and self.append_match_pairs()
            ):
                pass
            else:
                self._append_quiz(watch_choose_step(word, self.pool, choice_count=2))
        elif kind == "fillSlot":
            fill_candidates = [
                w
                for w in self._eligible_quiz_words()
                if w in self.fill_by_word and w in self.introduced_in_lesson
            ]
            fill_word = self._pick_least_used_word(fill_candidates)
            if fill_word:
                self.append(fill_slot_step(self.fill_by_word[fill_word]))
            else:
                choice_count = 2 if self.stone <= 2 else 4
                self._append_quiz(
                    watch_choose_step(word, self.pool, choice_count=choice_count)
                )
        else:
            choice_count = 2 if self.stone <= 2 else 4
            self._append_quiz(watch_choose_step(word, self.pool, choice_count=choice_count))
        return True

    def _would_exceed_density_cap(self, word: str | None) -> bool:
        if not word:
            return False
        window = repetition_rule(self.stone, "density_window")
        cap_limit = repetition_rule(self.stone, "density_max_in_window")
        recent: list[str] = []
        for step in self.steps:
            recent.extend(_step_graded_answer_ids(step))
        recent = recent[-(window - 1):]
        return recent.count(word) >= cap_limit

    def _append_quiz(self, step: dict, *, _spacing_guard: bool = True) -> None:
        if len(self.steps) >= self._step_limit():
            return
        answer = step.get("answerWordId")
        if answer and self.steps:
            last = self.steps[-1]
            last_answer = _graded_answer_id(last)
            if (
                last_answer == answer
                and not _allows_teach_intro_confirm_pair(last, step)
            ):
                alt = self._pick_review_word()
                if alt and alt != answer:
                    kind = step.get("kind")
                    if kind in {"fillSlot", "phraseSlot"}:
                        step = watch_choose_step(
                            alt, self.pool, choice_count=step.get("choiceCount", 2)
                        )
                    elif kind == "translationChoose":
                        if self.stone == 1:
                            step = stone1_translation_choose_step(alt, self.pool)
                        else:
                            step = translation_choose_step(
                                alt, self.pool, choice_count=step.get("choiceCount", 2)
                            )
                    elif kind == "wordPickVideo":
                        step = word_pick_video_step(alt, self.pool)
                    else:
                        step = watch_choose_step(
                            alt, self.pool, choice_count=step.get("choiceCount", 2)
                        )
                    answer = step.get("answerWordId")
                else:
                    return
        below_min_steps = len(self.steps) < STONE_MIN_STEPS.get(
            self.stone, MIN_MODULE_STEPS
        )
        if not below_min_steps and answer and self._would_exceed_density_cap(answer):
            alt = self._pick_review_word()
            if alt and alt != answer and not self._would_exceed_density_cap(alt):
                kind = step.get("kind")
                if kind == "translationChoose":
                    if self.stone == 1:
                        step = stone1_translation_choose_step(alt, self.pool)
                    else:
                        step = translation_choose_step(alt, self.pool, choice_count=4)
                elif kind == "wordPickVideo":
                    step = word_pick_video_step(alt, self.pool)
                else:
                    step = watch_choose_step(alt, self.pool, choice_count=2)
            elif self._would_exceed_density_cap(answer):
                return
        kind = step.get("kind")
        needs_lesson_intro = (
            answer
            and answer not in PHRASE_IDS
            and answer not in self._introduced_pool()
        )
        if needs_lesson_intro and kind != "watchChoose":
            step = watch_choose_step(answer, self.pool, choice_count=2)
            kind = step.get("kind")
        if kind == "watchChoose" and self.steps:
            last = self.steps[-1]
            if (
                last.get("kind") == "watchChoose"
                and last.get("answerWordId") == answer
            ):
                step = word_pick_video_step(answer, self.pool)
                kind = step.get("kind")
        is_new_intro = self._would_be_new_sign_intro(step)
        if _spacing_guard:
            if is_new_intro and self._intro_streak >= MAX_BACK_TO_BACK_NEW_INTROS:
                self._flush_pending_intro_batch()
            elif (
                not is_new_intro
                and self._pending_intro_words
                and step.get("kind") in QUIZ_KINDS
            ):
                self._flush_pending_intro_batch()
        was_new_intro = is_new_intro
        self._maybe_break_rhythm()
        kind = step["kind"]
        if kind == self.last_kind and kind in QUIZ_KINDS:
            word = step.get("answerWordId")
            # Keep the first exposure as watchChoose (maps to the teach intro in-app).
            if word and word in self._introduced_pool():
                pending_intro_confirm = (
                    self._last_new_intro_word is not None
                    and word == self._last_new_intro_word
                )
                if pending_intro_confirm:
                    pass
                elif kind == "watchChoose" and word in self._introduced_pool():
                    step = word_pick_video_step(word, self.pool)
                elif kind == "translationChoose":
                    step = watch_choose_step(
                        word,
                        self.pool,
                        choice_count=step.get("choiceCount", 4),
                    )
                elif kind == "wordPickVideo":
                    step = watch_choose_step(
                        word,
                        self.pool,
                        choice_count=step.get("choiceCount", 2),
                    )
                was_new_intro = self._would_be_new_sign_intro(step)
        step = self._coerce_step_pacing(step)
        answer = step.get("answerWordId")
        kind = step.get("kind")
        if answer and kind in RECOGNITION_KINDS:
            existing = self._recognition_modality_by_word.get(answer)
            if existing and existing != kind:
                choice_count = 4 if self.stone >= 2 else 2
                if self.stone == 1:
                    step = stone1_translation_choose_step(answer, self.pool)
                else:
                    step = translation_choose_step(
                        answer, self.pool, choice_count=choice_count
                    )
                kind = step.get("kind")
            if kind in RECOGNITION_KINDS and answer:
                self._recognition_modality_by_word[answer] = kind
        self.append(step)
        if was_new_intro:
            intro_word = step.get("answerWordId")
            if intro_word:
                self._last_new_intro_word = intro_word
                self._register_pending_intro(intro_word)
        else:
            answer = step.get("answerWordId")
            if answer and answer == self._last_new_intro_word:
                self._last_new_intro_word = None

    def _phrase_video_exercise_used(self, phrase_id: str) -> bool:
        return any(
            _phrase_video_exercise_id(step) == phrase_id for step in self.steps
        )

    def _coerce_step_pacing(self, step: dict) -> dict:
        if self._would_be_new_sign_intro(step):
            return step
        if _pacing_ok(self.steps, step):
            return step
        alt = _remediate_pacing_step(
            step,
            self.steps,
            self.pool,
            self.fill_by_word,
            introduced=self._introduced_pool(),
        )
        return alt or step

    def _apply_beat(self, beat: str) -> bool:
        if len(self.steps) >= self._step_limit():
            return False

        if beat == "warmUp":
            if self.stone == 1:
                return False
            words = self._warmup_word_pool()
            if not words:
                return False
            word = words[(self.unit["sortOrder"] + self.stone + self._slot) % len(words)]
            self._slot += 1
            choice_count = 4 if self.stone >= 2 else 2
            self._append_quiz(
                watch_choose_step(word, self.pool, choice_count=choice_count)
            )
            return True

        if beat == "newSignTeach":
            if self.new_teaches_in_lesson >= self.max_new_teaches:
                return self._apply_beat("recognitionQuiz")
            word = self._next_untaught_vocab()
            if not word:
                return self._apply_beat("recognitionQuiz")
            self.new_teaches_in_lesson += 1
            self.append_teach_block(word)
            return True

        if beat == "easyConfirm":
            word = self.last_taught_word
            if not word or word in PHRASE_IDS:
                candidates = [
                    w
                    for w in self.taught_words()
                    if w in self._introduced_pool() and w not in PHRASE_IDS
                ]
                word = self._pick_least_used_word(candidates) or self._pick_review_word()
            if not word:
                return False
            last = self.steps[-1] if self.steps else None
            if last and last.get("answerWordId") == word:
                return True
            self._append_quiz(
                varied_confirm_step(
                    word,
                    self.pool,
                    len(self.steps) + self._slot,
                    choice_count=2,
                )
            )
            return True

        if beat == "recognitionQuiz":
            eligible = self._eligible_quiz_words()
            if (
                self.last_taught_word
                and self.last_taught_word in eligible
                and len(eligible) <= 1
            ):
                self._append_quiz(
                    word_pick_video_step(self.last_taught_word, self.pool)
                )
                return True
            word = self._pick_review_word()
            if not word and len(eligible) >= 2:
                word = self._pick_least_used_word(eligible)
            if not word:
                word = self.last_taught_word
            if not word:
                return False
            if self.stone == 1:
                self._append_stone1_recognition_quiz(word)
                return True
            choice_count = 4 if self.stone >= 2 else 2
            if self.stone == 2:
                if self.last_kind == "watchChoose":
                    self._append_quiz(word_pick_video_step(word, self.pool))
                else:
                    self._append_quiz(
                        watch_choose_step(word, self.pool, choice_count=choice_count)
                    )
            elif self.last_kind in SIGN_TO_WORD_KINDS:
                self._append_quiz(word_pick_video_step(word, self.pool))
            elif self.last_kind in WORD_TO_SIGN_KINDS:
                pick = (len(self.steps) + self._slot) % 3
                if pick == 2:
                    self._append_quiz(
                        translation_choose_step(word, self.pool, choice_count=4)
                    )
                else:
                    self._append_quiz(
                        watch_choose_step(word, self.pool, choice_count=4)
                    )
            else:
                pick = (len(self.steps) + self._slot) % 4
                if pick in (0, 1):
                    self._append_quiz(word_pick_video_step(word, self.pool))
                elif pick == 2:
                    self._append_quiz(
                        watch_choose_step(word, self.pool, choice_count=4)
                    )
                else:
                    self._append_quiz(
                        translation_choose_step(word, self.pool, choice_count=4)
                    )
            return True

        if beat == "useInContext":
            for word in PHRASE_CONTEXT_SIGN_SEQUENCES.get(self.unit["id"], {}):
                if self._append_phrase_context_sign_sequence(word):
                    self._slot += 1
                    return True
            for word in PHRASE_FILL_SLOTS.get(self.unit["id"], {}):
                if self._append_phrase_context_fill(word):
                    self._slot += 1
                    return True
            fill_candidates = [
                w
                for w in self.taught_words()
                if w in self.introduced_in_lesson and w in self.fill_by_word
            ]
            if fill_candidates:
                word = self._pick_least_used_word(fill_candidates)
                if word:
                    self._slot += 1
                    self.append(fill_slot_step(self.fill_by_word[word]))
                    return True
            return self._apply_beat("recognitionQuiz")

        if beat == "videoPickChallenge":
            introduced = [
                w
                for w in self.taught_words()
                if w in self._introduced_pool() and w not in PHRASE_IDS
            ]
            word = self._pick_least_used_word(introduced)
            if not word:
                return self._apply_beat("recognitionQuiz")
            self._append_quiz(word_pick_video_step(word, self.pool))
            return True

        if beat == "funMixed":
            if self.stone <= 2:
                if self._apply_beat("translationChoose"):
                    return True
                if self._apply_beat("matchPairs"):
                    return True
                return self._apply_beat("recognitionQuiz")
            if self._apply_beat("videoPickChallenge"):
                return True
            if self._apply_beat("translationChoose"):
                return True
            return self._apply_beat("recognitionQuiz")

        if beat == "matchPairs":
            if self.last_kind == "matchPairs":
                return self._apply_beat("recognitionQuiz")
            if len(self.match_pair_eligible()) < MIN_MATCH_PAIRS_ELIGIBLE:
                return self._apply_beat("recognitionQuiz")
            if self.append_match_pairs(pair_count=3):
                return True
            return self._apply_beat("recognitionQuiz")

        if beat == "translationChoose":
            word = self._pick_review_word()
            if not word:
                return False
            if self.stone == 1:
                self._append_quiz(stone1_translation_choose_step(word, self.pool))
            else:
                choice_count = 4
                self._append_quiz(
                    translation_choose_step(word, self.pool, choice_count=choice_count)
                )
            return True

        if beat == "crossUnitReview":
            word = self._pick_cross_unit_word()
            if not word:
                return self._apply_beat("recognitionQuiz")
            slot = len(self.steps) + self._slot
            self._slot += 1
            cap = STONE_RECOGNITION_SHARE_CAP.get(self.stone, 0.55)
            if self.stone == 3 and self._recognition_share() >= cap - 0.05:
                self._append_quiz(watch_choose_step(word, self.pool, choice_count=4))
            elif slot % 2 == 0:
                self._append_quiz(word_pick_video_step(word, self.pool))
            else:
                self._append_quiz(watch_choose_step(word, self.pool, choice_count=4))
            return True

        if beat == "aslTip":
            if self.stone == 1 and len(self.introduced_in_lesson) < 2:
                return self._apply_beat("recognitionQuiz")
            if any(step.get("kind") == "aslTip" for step in self.steps):
                return True
            tip, next_cursor = alloc_asl_tip(
                self.state.asl_tip_used_ids,
                self.state.asl_tip_cursor,
            )
            self.state.asl_tip_cursor = next_cursor
            self._slot += 1
            if len(self.steps) >= self._step_limit():
                return False
            self.steps.append(asl_tip_step(tip))
            self.last_kind = "aslTip"
            return True

        if beat == "yourTurn":
            if self.stone < 2:
                return self._apply_beat("recognitionQuiz")
            used_your_turn = {
                step.get("wordId")
                for step in self.steps
                if step.get("kind") == "yourTurn" and step.get("wordId")
            }
            word = None
            if (
                self.last_taught_word
                and self.last_taught_word not in PHRASE_IDS
                and self.last_taught_word not in used_your_turn
            ):
                word = self.last_taught_word
            if not word:
                candidates = [
                    w
                    for w in self.taught_words()
                    if w not in PHRASE_IDS and w not in used_your_turn
                ]
                word = self._pick_least_used_word(candidates)
            if not word:
                word = self._pick_least_used_word(
                    [w for w in self.taught_words() if w not in PHRASE_IDS]
                )
            if not word:
                return self._apply_beat("recognitionQuiz")
            self.steps.append(your_turn_step(word))
            self.last_kind = "yourTurn"
            return True

        if beat == "watchChoosePad":
            word = self._pick_review_word()
            if not word:
                return False
            choice_count = 2 if self.stone <= 2 else 4
            self._append_quiz(watch_choose_step(word, self.pool, choice_count=choice_count))
            return True

        if beat == "phraseSprinkle":
            return True

        if beat == "fillSlotPad":
            if self.append_fill_slot():
                return True
            for word in PHRASE_CONTEXT_SIGN_SEQUENCES.get(self.unit["id"], {}):
                if self._append_phrase_context_sign_sequence(word):
                    return True
            for word in PHRASE_FILL_SLOTS.get(self.unit["id"], {}):
                if self._append_phrase_context_fill(word):
                    return True
            return self._apply_beat("useInContext")

        return False


def _graded_answer_word_ids(step: dict) -> list[str]:
    """Word ids that count as distinct correct answers for diversity checks."""
    kind = step.get("kind")
    if kind == "matchPairs":
        return list(step.get("pairWordIds") or [])
    if kind == "signSequence":
        phrase = step.get("wordId")
        return [phrase] if phrase else []
    if kind in QUIZ_KINDS or kind in {"fillGap", "meaningPick", "watchPick2", "watchPick4", "watchThenPick"}:
        answer = step.get("answerWordId")
        return [answer] if answer else []
    return []


def _step_answer_id(step: dict):
    """Representative 'correct answer' id for a graded step, else None."""
    kind = step["kind"]
    if kind == "matchPairs":
        pairs = step.get("pairWordIds", [])
        return ("matchPairs", tuple(pairs)) if pairs else None
    if kind == "signSequence":
        return ("signSequence", step.get("wordId"))
    if kind in ("aslTip", "yourTurn", "teach", "selfSign"):
        return None
    return step.get("answerWordId")


def _tail_kind_streak(result: list[dict], kind: str) -> int:
    streak = 0
    for step in reversed(result):
        if step.get("kind") == kind:
            streak += 1
        else:
            break
    return streak


def _quiz_family(kind: str | None) -> str | None:
    if kind in SIGN_TO_WORD_KINDS:
        return "signToWord"
    if kind in WORD_TO_SIGN_KINDS:
        return "wordToSign"
    return None


def _tail_family_streak(result: list[dict], family: str) -> int:
    streak = 0
    for step in reversed(result):
        step_kind = step.get("kind")
        if step_kind == "teach" or step_kind in RHYTHM_BREAK_KINDS:
            break
        if _quiz_family(step_kind) == family:
            streak += 1
        elif _quiz_family(step_kind) is not None:
            break
    return streak


def _would_exceed_family_streak(
    result: list[dict],
    cand: dict,
    max_run: int = 1,
) -> bool:
    family = _quiz_family(cand.get("kind"))
    if not family or not result:
        return False
    return _tail_family_streak(result, family) >= max_run


def _would_exceed_kind_streak(
    result: list[dict],
    cand: dict,
    max_run: int = MAX_CONSECUTIVE_SAME_KIND,
) -> bool:
    kind = cand.get("kind")
    if not result or not kind:
        return False
    return _tail_kind_streak(result, kind) >= max_run


def _remediate_pacing_step(
    step: dict,
    prior: list[dict],
    pool: list[str],
    fill_by_word: dict[str, dict] | None = None,
    introduced: set[str] | None = None,
) -> dict | None:
    word = step.get("answerWordId")
    if not word:
        return None
    kind = step.get("kind")
    choice_count = step.get("choiceCount", 4)
    candidates: list[dict] = []
    if fill_by_word and word in fill_by_word:
        if introduced is None or word in introduced:
            candidates.append(fill_slot_step(fill_by_word[word]))
    if kind != "watchChoose":
        candidates.append(
            watch_choose_step(word, pool, choice_count=min(choice_count, 4))
        )
    if kind != "wordPickVideo":
        candidates.append(word_pick_video_step(word, pool))
    if kind != "translationChoose":
        candidates.append(
            translation_choose_step(word, pool, choice_count=choice_count)
        )
    for alt in candidates:
        if introduced is not None and _step_requires_prior_intro(alt):
            answer = alt.get("answerWordId")
            if answer and answer not in introduced:
                continue
        if _pacing_ok(prior, alt):
            return alt
    return None


def _pacing_ok(result: list[dict], cand: dict) -> bool:
    if _would_exceed_kind_streak(result, cand):
        return False
    return not _would_exceed_family_streak(result, cand)


INTRO_CONFIRM_KINDS = frozenset(
    {"watchChoose", "translationChoose", "wordPickVideo"}
)

GRADED_EXERCISE_KINDS = QUIZ_KINDS | {
    "fillSlot",
    "phraseSlot",
    "matchPairs",
    "signSequence",
}


def _is_graded_exercise_step(step: dict) -> bool:
    return step.get("kind") in GRADED_EXERCISE_KINDS


def _step_graded_answer_ids(step: dict) -> list[str]:
    return sorted(_graded_step_answer_tokens(step))


def _graded_step_answer_tokens(step: dict) -> frozenset[str]:
    """Sign / phrase ids that count as the step's correct answer for spacing."""
    kind = step.get("kind")
    tokens: set[str] = set()
    if kind == "matchPairs":
        tokens.update(step.get("pairWordIds") or [])
        answer = step.get("answerWordId")
        if answer:
            tokens.add(answer)
    elif kind == "signSequence":
        phrase = step.get("wordId")
        if phrase:
            tokens.add(phrase)
    elif kind in QUIZ_KINDS | {"fillSlot", "phraseSlot"}:
        answer = step.get("answerWordId")
        if answer:
            tokens.add(answer)
        phrase = step.get("wordId")
        if phrase and phrase in PHRASE_IDS:
            tokens.add(phrase)
    return frozenset(tokens)


def _graded_answer_id(step: dict) -> str | None:
    """Correct-answer word id for a graded pick step, else None."""
    kind = step.get("kind")
    if kind in QUIZ_KINDS or kind in {"fillSlot", "phraseSlot"}:
        return step.get("answerWordId")
    return None


def _adjacent_graded_answer_conflict(prev: dict, curr: dict) -> bool:
    """True when two consecutive graded exercises share a sign or phrase answer."""
    if not _is_graded_exercise_step(prev) or not _is_graded_exercise_step(curr):
        return False
    if _allows_teach_intro_confirm_pair(prev, curr):
        return False
    prev_tokens = _graded_step_answer_tokens(prev)
    curr_tokens = _graded_step_answer_tokens(curr)
    if not prev_tokens or not curr_tokens:
        return False
    return bool(prev_tokens & curr_tokens)


def _allows_teach_intro_confirm_pair(prev: dict, curr: dict) -> bool:
    """Only teach → immediate confirm may repeat the same answer back-to-back."""
    return (
        prev.get("kind") == "teach"
        and curr.get("kind") in INTRO_CONFIRM_KINDS
        and prev.get("wordId") == curr.get("answerWordId")
    )


def enforce_no_adjacent_same_graded_answer(
    steps: list[dict],
    pool: list[str],
) -> list[dict]:
    """Swap graded steps so no two consecutive picks share the same answer."""
    if len(steps) < 2:
        return steps

    earliest = _answer_first_intro_index(steps)
    result = list(steps)

    for _ in range(len(result) * 3):
        changed = False
        for index in range(1, len(result)):
            prev, curr = result[index - 1], result[index]
            if not _adjacent_graded_answer_conflict(prev, curr):
                continue

            prev_tokens = _graded_step_answer_tokens(prev)
            curr_tokens = _graded_step_answer_tokens(curr)
            swap_idx = None
            for later in range(index + 1, len(result)):
                later_tokens = _graded_step_answer_tokens(result[later])
                if later_tokens & curr_tokens:
                    continue
                if later == index + 1 and later_tokens & prev_tokens:
                    continue
                if not _swap_preserves_intro_order(earliest, index, later, result):
                    continue
                trial = list(result)
                trial[index], trial[later] = trial[later], trial[index]
                if _adjacent_graded_answer_conflict(trial[index - 1], trial[index]):
                    continue
                if index + 1 < len(trial) and _adjacent_graded_answer_conflict(
                    trial[index], trial[index + 1]
                ):
                    continue
                swap_idx = later
                break

            if swap_idx is not None:
                result[index], result[swap_idx] = result[swap_idx], result[index]
                changed = True
                break

            forbidden = prev_tokens | curr_tokens
            alt = next(
                (
                    word
                    for word in pool
                    if word not in forbidden and word not in PHRASE_IDS
                ),
                None,
            )
            if alt and curr.get("kind") in INTRO_CONFIRM_KINDS:
                kind = curr.get("kind")
                if kind == "wordPickVideo":
                    result[index] = word_pick_video_step(alt, pool)
                elif kind == "translationChoose":
                    result[index] = translation_choose_step(
                        alt, pool, choice_count=curr.get("choiceCount", 2)
                    )
                else:
                    result[index] = watch_choose_step(
                        alt, pool, choice_count=curr.get("choiceCount", 2)
                    )
                changed = True
                break

            if curr.get("kind") in {"fillSlot", "phraseSlot", "signSequence", "matchPairs"}:
                if alt:
                    if curr.get("kind") == "matchPairs":
                        result[index] = translation_choose_step(
                            alt,
                            pool,
                            choice_count=curr.get("choiceCount", 4),
                        )
                    else:
                        result[index] = watch_choose_step(
                            alt, pool, choice_count=curr.get("choiceCount", 2)
                        )
                    changed = True
                    break
                if curr.get("kind") in {"fillSlot", "phraseSlot"}:
                    drop = result.pop(index)
                    _ = drop
                    changed = True
                    break

        if not changed:
            break

    return result


def _is_intro_confirm_pair(prev: dict, cand: dict) -> bool:
    """Allow teach → immediate recognition on the same new sign only."""
    return _allows_teach_intro_confirm_pair(prev, cand)


def _variety_ok(result: list[dict], cand: dict) -> bool:
    # No identical correct answer twice in a row (except intro → confirm).
    if result:
        prev_id = _step_answer_id(result[-1])
        if prev_id is not None and prev_id == _step_answer_id(cand):
            if not _is_intro_confirm_pair(result[-1], cand):
                return False
    return _pacing_ok(result, cand)


def enforce_step_pacing(
    steps: list[dict],
    pool: list[str],
    fill_by_word: dict[str, dict] | None = None,
    introduced_at_start: set[str] | None = None,
    unit_words: set[str] | None = None,
) -> list[dict]:
    """Keep lesson order when possible, but swap or retarget steps so no more
    than two identical exercise types appear consecutively."""
    if len(steps) <= 1:
        return steps

    pending = list(steps)
    result: list[dict] = []
    introduced: set[str] = set(introduced_at_start or set())
    defer_budget = len(pending) * 3

    index = 0
    while index < len(pending):
        step = pending[index]
        work = step
        if not _pacing_ok(result, work):
            swapped = False
            for later in range(index + 1, len(pending)):
                candidate = pending[later]
                if not _pacing_ok(result, candidate):
                    continue
                if _step_requires_prior_intro(candidate):
                    answer = candidate.get("answerWordId")
                    if answer and answer not in introduced:
                        continue
                pending[index], pending[later] = pending[later], pending[index]
                work = pending[index]
                swapped = True
                break
            if not swapped:
                for _ in range(4):
                    alt = _remediate_pacing_step(
                        work,
                        result,
                        pool,
                        fill_by_word,
                        introduced=introduced,
                    )
                    if not alt or alt == work:
                        break
                    work = alt
                    if _pacing_ok(result, work):
                        break

        if not _pacing_ok(result, work) and defer_budget > 0:
            pending.append(pending.pop(index))
            defer_budget -= 1
            continue

        result.append(work)
        _register_step_intro(introduced, work)
        index += 1

    return result


def _step_requires_prior_intro(step: dict) -> bool:
    kind = step.get("kind")
    answer = step.get("answerWordId")
    if not answer:
        return False
    return kind in QUIZ_KINDS and kind != "watchChoose"


def _is_runtime_new_intro(
    step: dict,
    introduced: set[str],
    unit_words: set[str],
) -> bool:
    kind = step.get("kind")
    if kind not in RUNTIME_INTRO_KINDS:
        return False
    word = step.get("answerWordId")
    if not word or word not in unit_words or word in PHRASE_IDS:
        return False
    return word not in introduced


def anchor_intro_confirm_after_intro(
    steps: list[dict],
    unit_words: set[str],
    introduced_at_start: set[str] | None = None,
) -> list[dict]:
    """Keep the post-intro recognition pick directly after each new-sign intro."""
    introduced: set[str] = set(introduced_at_start or set())
    stone_introduced: set[str] = set()
    pending = list(steps)
    result: list[dict] = []

    while pending:
        step = pending.pop(0)
        if _is_runtime_new_intro(step, stone_introduced, unit_words):
            word = step.get("answerWordId")
            result.append(step)
            _register_step_intro(introduced, step)
            if word and word in unit_words:
                stone_introduced.add(word)
            if word:
                confirm_idx = None
                for index, cand in enumerate(pending):
                    if (
                        cand.get("answerWordId") == word
                        and cand.get("kind") in INTRO_CONFIRM_KINDS
                        and not _is_runtime_new_intro(
                            cand, stone_introduced, unit_words
                        )
                    ):
                        confirm_idx = index
                        break
                if confirm_idx is not None:
                    result.append(pending.pop(confirm_idx))
            continue
        result.append(step)
        _register_step_intro(introduced, step)

    return result


def enforce_no_adjacent_new_intros(
    steps: list[dict],
    unit_words: set[str],
    introduced_at_start: set[str] | None = None,
    pool: list[str] | None = None,
) -> list[dict]:
    """Never allow back-to-back new-sign intros; insert a recognition pick between."""
    if len(steps) < 2:
        return steps

    introduced = set(introduced_at_start or set())
    result: list[dict] = []
    intro_streak = 0
    distractor_pool = pool or []

    for step in steps:
        if _is_runtime_new_intro(step, introduced, unit_words):
            if intro_streak >= MAX_BACK_TO_BACK_NEW_INTROS:
                prev_word = result[-1].get("answerWordId") if result else None
                if prev_word and distractor_pool:
                    result.append(
                        varied_confirm_step(
                            prev_word,
                            distractor_pool,
                            len(result),
                            choice_count=2,
                            avoid_watch_choose=True,
                        )
                    )
                intro_streak = 0
            result.append(step)
            _register_step_intro(introduced, step)
            intro_streak += 1
        else:
            result.append(step)
            _register_step_intro(introduced, step)
            answer = step.get("answerWordId")
            if answer and step.get("kind") in INTRO_CONFIRM_KINDS:
                intro_streak = 0

    return result


def _register_step_intro(introduced: set[str], step: dict) -> None:
    if step.get("kind") == "teach":
        word = step.get("wordId")
        if word:
            introduced.add(word)
    if step.get("kind") == "watchChoose":
        answer = step.get("answerWordId")
        if answer:
            introduced.add(answer)
    elif step.get("kind") in {"signSequence", "phraseSlot"}:
        phrase = step.get("wordId")
        if phrase:
            introduced.add(phrase)
        for wid in step.get("sequenceWordIds", []):
            if wid:
                introduced.add(wid)


def _phrase_video_exercise_id(step: dict) -> str | None:
    kind = step.get("kind")
    if kind in {"signSequence", "phraseSlot"}:
        return step.get("wordId")
    if kind == "fillSlot":
        word_id = step.get("wordId")
        if word_id in PHRASE_IDS:
            return word_id
    return None


def dedupe_teach_steps_per_word(steps: list[dict]) -> list[dict]:
    """At most one explicit teach step per word per lesson."""
    seen: set[str] = set()
    result: list[dict] = []
    for step in steps:
        if step.get("kind") == "teach":
            word = step.get("wordId")
            if word and word in seen:
                continue
            if word:
                seen.add(word)
        result.append(step)
    return result


def path_words_taught_in_lesson(steps: list[dict]) -> set[str]:
    """Words/phrases counted as taught on the path from final lesson steps."""
    taught: set[str] = set()
    for step in steps:
        kind = step.get("kind")
        if kind == "teach":
            word = step.get("wordId")
            if word:
                taught.add(word)
        elif kind in {"signSequence", "phraseSlot"}:
            if step.get("phrasePreview"):
                continue
            for wid in step.get("sequenceWordIds", []):
                if wid:
                    taught.add(wid)
            phrase = step.get("wordId")
            if phrase:
                taught.add(phrase)
    return taught


def dedupe_phrase_video_exercises(steps: list[dict]) -> list[dict]:
    """At most one phrase-video exercise (signSequence or phraseSlot) per phrase per lesson."""
    seen_phrase: set[str] = set()
    result: list[dict] = []
    for step in steps:
        kind = step.get("kind")
        if kind in {"signSequence", "phraseSlot"}:
            phrase_id = step.get("wordId")
            if phrase_id and phrase_id in seen_phrase:
                continue
            if phrase_id:
                seen_phrase.add(phrase_id)
        result.append(step)
    return result


def separate_adjacent_phrase_video_exercises(steps: list[dict]) -> list[dict]:
    """Drop back-to-back steps that replay the same phrase clip."""
    if len(steps) < 2:
        return steps
    result: list[dict] = [steps[0]]
    for step in steps[1:]:
        prev_id = _phrase_video_exercise_id(result[-1])
        curr_id = _phrase_video_exercise_id(step)
        if prev_id and curr_id and prev_id == curr_id:
            continue
        result.append(step)
    return result


def _match_pairs_alternate_step(
    step: dict,
    pool: list[str],
    slot: int = 0,
) -> dict:
    """Replace a matchPairs step with a single-sign recognition check."""
    pairs = step.get("pairWordIds") or []
    word = step.get("answerWordId") or (pairs[0] if pairs else None)
    if not word or word in PHRASE_IDS:
        for candidate in pairs:
            if candidate not in PHRASE_IDS:
                word = candidate
                break
    if not word:
        word = next((w for w in pool if w not in PHRASE_IDS), pool[0] if pool else None)
    if not word:
        return step
    return varied_confirm_step(word, pool, slot, choice_count=2)


def separate_adjacent_match_pairs(steps: list[dict], pool: list[str]) -> list[dict]:
    """Never stack two matchPairs exercises in a row."""
    if len(steps) < 2:
        return steps

    result = list(steps)
    for _ in range(len(result) * 3):
        changed = False
        for index in range(1, len(result)):
            if result[index - 1].get("kind") != "matchPairs":
                continue
            if result[index].get("kind") != "matchPairs":
                continue

            swap_idx = None
            for later in range(index + 1, len(result)):
                if result[later].get("kind") == "matchPairs":
                    continue
                swap_idx = later
                break

            if swap_idx is not None:
                result[index], result[swap_idx] = result[swap_idx], result[index]
                changed = True
                break

            result[index] = _match_pairs_alternate_step(result[index], pool, index)
            changed = True
            break

        if not changed:
            break

    return result


def _is_teach_confirm_pair(prev: dict, step: dict) -> bool:
    if prev.get("kind") != "teach":
        return False
    word = prev.get("wordId")
    return (
        bool(word)
        and step.get("kind") in INTRO_CONFIRM_KINDS
        and step.get("answerWordId") == word
    )


def _trailing_teach_confirm_pairs(steps: list[dict]) -> int:
    count = 0
    index = len(steps) - 1
    while index >= 1:
        if _is_teach_confirm_pair(steps[index - 1], steps[index]):
            count += 1
            index -= 2
        else:
            break
    return count


def strip_your_turn_from_early_stones(
    steps: list[dict],
    pool: list[str],
    *,
    stone: int,
) -> list[dict]:
    """Replace yourTurn with varied recognition on stone 1 (reserved for 2–4)."""
    if stone >= 2:
        return steps
    result: list[dict] = []
    for step in steps:
        if step.get("kind") != "yourTurn":
            result.append(step)
            continue
        word = step.get("wordId")
        if not word:
            continue
        result.append(
            varied_confirm_step(
                word,
                pool,
                len(result),
                choice_count=2,
            )
        )
    return result


def enforce_one_recognition_modality(
    steps: list[dict],
    pool: list[str],
    *,
    stone: int,
) -> list[dict]:
    """Never use both watchChoose and wordPickVideo for the same answer in one lesson."""
    seen: dict[str, str] = {}
    result: list[dict] = []
    for step in steps:
        kind = step.get("kind")
        answer = step.get("answerWordId")
        if kind in RECOGNITION_KINDS and answer:
            existing = seen.get(answer)
            if existing:
                choice_count = 4 if stone >= 2 else 2
                if stone == 1:
                    step = stone1_translation_choose_step(answer, pool)
                else:
                    step = translation_choose_step(
                        answer, pool, choice_count=choice_count
                    )
                kind = step.get("kind")
            else:
                seen[answer] = kind
        result.append(step)
    return result


def cap_your_turn_steps(steps: list[dict], *, stone: int, max_count: int = 1) -> list[dict]:
    """Keep at most `max_count` yourTurn beats per lesson."""
    if max_count <= 0:
        return [step for step in steps if step.get("kind") != "yourTurn"]
    kept = 0
    result: list[dict] = []
    for step in steps:
        if step.get("kind") == "yourTurn":
            if kept >= max_count:
                continue
            kept += 1
        result.append(step)
    return result


def enforce_max_teach_confirm_pairs(
    steps: list[dict],
    pool: list[str],
    max_pairs: int = MAX_CONSECUTIVE_TEACH_CONFIRM_PAIRS,
) -> list[dict]:
    """Never stack more than max_pairs teach→intro-confirm sequences without a break."""
    if len(steps) < 2:
        return steps

    result: list[dict] = []
    streak = 0
    index = 0

    def append_break() -> None:
        nonlocal streak
        taught = [
            prior.get("wordId")
            for prior in result
            if prior.get("kind") == "teach" and prior.get("wordId")
        ]
        break_word = taught[-1] if taught else None
        if break_word and pool:
            result.append(
                varied_confirm_step(
                    break_word,
                    pool,
                    len(result),
                    choice_count=2,
                    avoid_watch_choose=True,
                )
            )
        streak = 0

    while index < len(steps):
        step = steps[index]
        if step.get("kind") == "teach":
            if streak >= max_pairs:
                upcoming = steps[index + 1] if index + 1 < len(steps) else None
                if (
                    upcoming
                    and upcoming.get("kind") in INTRO_CONFIRM_KINDS
                    and not _is_teach_confirm_pair(step, upcoming)
                ):
                    result.append(upcoming)
                    streak = 0
                    index += 1
                else:
                    append_break()
            if (
                index + 1 < len(steps)
                and _is_teach_confirm_pair(step, steps[index + 1])
            ):
                result.append(step)
                result.append(steps[index + 1])
                streak += 1
                index += 2
                continue
            result.append(step)
            index += 1
            continue
        if step.get("kind") in RHYTHM_BREAK_KINDS or step.get("kind") in {
            "matchPairs",
            "fillSlot",
            "yourTurn",
            "aslTip",
            "signSequence",
            "phraseSlot",
        }:
            streak = 0
        result.append(step)
        index += 1
    return result


def anchor_teach_confirm_pairs(steps: list[dict]) -> list[dict]:
    """Keep each teach step followed immediately by its intro confirm quiz."""
    confirms_by_answer: dict[str, dict] = {}
    body: list[dict] = []
    for step in steps:
        answer = step.get("answerWordId")
        if answer and step.get("kind") in INTRO_CONFIRM_KINDS:
            confirms_by_answer.setdefault(answer, step)
        else:
            body.append(step)

    result: list[dict] = []
    used_confirms: set[str] = set()
    for step in body:
        result.append(step)
        if step.get("kind") != "teach":
            continue
        word = step.get("wordId")
        if not word or word in used_confirms:
            continue
        if confirm := confirms_by_answer.get(word):
            result.append(confirm)
            used_confirms.add(word)

    for step in steps:
        answer = step.get("answerWordId")
        if (
            answer
            and step.get("kind") in INTRO_CONFIRM_KINDS
            and answer not in used_confirms
        ):
            result.append(step)
    return result


def anchor_phrase_preview_sign_sequences(steps: list[dict], unit_id: str) -> list[dict]:
    """Keep phrase-preview signSequence steps right after the trigger word's intro."""
    triggers = PHRASE_CONTEXT_SIGN_SEQUENCES.get(unit_id, {})
    if not triggers:
        return steps

    previews: dict[str, dict] = {}
    body: list[dict] = []
    for step in steps:
        phrase = step.get("wordId")
        if (
            step.get("kind") == "signSequence"
            and step.get("phrasePreview")
            and phrase in triggers.values()
        ):
            previews[phrase] = step
        else:
            body.append(step)
    if not previews:
        return steps

    result: list[dict] = []
    placed: set[str] = set()
    index = 0
    while index < len(body):
        step = body[index]
        result.append(step)
        if step.get("kind") == "teach":
            word = step.get("wordId")
            if word and word in triggers and word not in placed:
                phrase_id = triggers[word]
                preview = previews.get(phrase_id)
                if preview:
                    if (
                        index + 1 < len(body)
                        and body[index + 1].get("kind") in INTRO_CONFIRM_KINDS
                        and body[index + 1].get("answerWordId") == word
                    ):
                        index += 1
                        result.append(body[index])
                    result.append(preview)
                    placed.add(word)
        index += 1

    for phrase_id, preview in previews.items():
        if phrase_id not in {triggers[w] for w in placed}:
            result.append(preview)
    return result


def enforce_variety(
    steps: list[dict],
    introduced_at_start: set[str] | None = None,
    unit_words: set[str] | None = None,
) -> list[dict]:
    """Reorder (never drop) so no answer repeats back-to-back and no exercise
    type appears 3x in a row. Deterministic greedy: keep original order unless a
    constraint forces pulling a later step forward."""
    if len(steps) <= 2:
        return steps
    remaining = list(steps)
    result: list[dict] = []
    introduced: set[str] = set(introduced_at_start or set())
    stone_introduced: set[str] = set()
    prev_was_stone_new_intro = False
    rotation_budget = len(steps) * max(len(steps), 1)
    while remaining:
        chosen = None
        for idx, cand in enumerate(remaining):
            if not _variety_ok(result, cand):
                continue
            if (
                unit_words
                and prev_was_stone_new_intro
                and _is_runtime_new_intro(cand, stone_introduced, unit_words)
            ):
                continue
            if _step_requires_prior_intro(cand):
                answer = cand.get("answerWordId")
                if answer and answer not in introduced:
                    continue
            if cand.get("kind") == "phraseSlot":
                blocked = False
                for wid in (
                    {cand.get("answerWordId")}
                    | set(cand.get("distractorWordIds", []))
                ):
                    if wid and wid not in introduced:
                        blocked = True
                        break
                if blocked:
                    continue
            if cand.get("kind") == "matchPairs":
                blocked = False
                for wid in cand.get("pairWordIds", []):
                    if wid not in introduced:
                        blocked = True
                        break
                if blocked:
                    continue
            chosen = idx
            break
        if chosen is None:
            if len(remaining) > 1 and rotation_budget > 0:
                remaining.append(remaining.pop(0))
                rotation_budget -= 1
                continue
            chosen = 0  # Last resort on a single remaining step.
        step = remaining.pop(chosen)
        result.append(step)
        _register_step_intro(introduced, step)
        if unit_words:
            is_stone_new = _is_runtime_new_intro(step, stone_introduced, unit_words)
            answer = step.get("answerWordId")
            if answer and answer in unit_words:
                stone_introduced.add(answer)
            for wid in step.get("pairWordIds", []):
                if wid in unit_words:
                    stone_introduced.add(wid)
            prev_was_stone_new_intro = is_stone_new
    return result


def enforce_max_answer_density(
    steps: list[dict],
    window: int,
    max_in_window: int,
) -> list[dict]:
    """Swap steps so no answer appears more than max_in_window times in window."""
    if len(steps) <= window:
        return steps

    earliest = _answer_first_intro_index(steps)
    result = list(steps)

    for _ in range(len(result) * 2):
        changed = False
        for index in range(len(result)):
            answers = _step_graded_answer_ids(result[index])
            if not answers:
                continue
            start = max(0, index - window + 1)
            window_answers: list[str] = []
            for i in range(start, index + 1):
                window_answers.extend(_step_graded_answer_ids(result[i]))
            for answer in answers:
                if window_answers.count(answer) <= max_in_window:
                    continue
                recent = set(window_answers)
                swap_idx = None
                for later in range(index + 1, len(result)):
                    later_answers = _step_graded_answer_ids(result[later])
                    if not later_answers or any(a in recent for a in later_answers):
                        continue
                    if not _swap_preserves_intro_order(earliest, index, later, result):
                        continue
                    swap_idx = later
                    break
                if swap_idx is None:
                    continue
                result[index], result[swap_idx] = result[swap_idx], result[index]
                changed = True
                break
            if changed:
                break
        if not changed:
            break

    return result


def ensure_intro_before_quiz_steps(
    steps: list[dict],
    introduced_at_start: set[str],
    pool: list[str],
) -> list[dict]:
    """Insert watchChoose intros before graded steps that lack prior exposure."""
    introduced = set(introduced_at_start)
    result: list[dict] = []
    for step in steps:
        kind = step.get("kind")
        if kind in {"signSequence", "phraseSlot"}:
            for wid in step.get("sequenceWordIds", []):
                if wid:
                    introduced.add(wid)
            phrase = step.get("wordId")
            if phrase:
                introduced.add(phrase)
        answer = step.get("answerWordId")
        if (
            answer
            and answer not in PHRASE_IDS
            and kind in QUIZ_KINDS
            and kind != "watchChoose"
            and answer not in introduced
        ):
            result.append(watch_choose_step(answer, pool, choice_count=2))
            introduced.add(answer)
        result.append(step)
        if kind == "matchPairs":
            for wid in step.get("pairWordIds", []):
                if wid:
                    introduced.add(wid)
        if answer and kind in QUIZ_KINDS and answer:
            introduced.add(answer)
    return result


def assert_intro_before_quiz(
    steps: list[dict],
    introduced_at_start: set[str],
    unit_words: set[str],
) -> None:
    """Raise during generation when a graded answer precedes its intro."""
    introduced = set(introduced_at_start)
    for index, step in enumerate(steps):
        kind = step.get("kind")
        if kind in {"signSequence", "phraseSlot"}:
            for wid in step.get("sequenceWordIds", []):
                if wid:
                    introduced.add(wid)
            phrase = step.get("wordId")
            if phrase:
                introduced.add(phrase)
        if kind == "matchPairs":
            for wid in step.get("pairWordIds", []):
                if wid and wid not in introduced:
                    raise ValueError(
                        f"matchPairs pair {wid} before intro at step {index}"
                    )
                if wid:
                    introduced.add(wid)
        answer = step.get("answerWordId")
        if answer and kind in QUIZ_KINDS:
            if answer not in introduced and kind != "watchChoose":
                raise ValueError(
                    f"{kind} for {answer} before intro at step {index}"
                )
            if answer:
                introduced.add(answer)
        elif kind == "teach":
            wid = step.get("wordId")
            if wid:
                introduced.add(wid)


def _answer_first_intro_index(steps: list[dict]) -> dict[str, int]:
    """First step index where each answer word is introduced (watchChoose = teach)."""
    earliest: dict[str, int] = {}
    for index, step in enumerate(steps):
        answer = step.get("answerWordId")
        if not answer or answer in earliest:
            continue
        if step.get("kind") in {"watchChoose", "teach"}:
            earliest[answer] = index
    return earliest


def _position_allowed_for_answer(
    earliest: dict[str, int],
    index: int,
    step: dict,
) -> bool:
    answer = step.get("answerWordId")
    if not answer:
        return True
    intro_index = earliest.get(answer, index)
    if step.get("kind") == "watchChoose":
        return index >= intro_index
    return index > intro_index


def _swap_preserves_intro_order(
    earliest: dict[str, int],
    left: int,
    right: int,
    result: list[dict],
) -> bool:
    trial = list(result)
    trial[left], trial[right] = trial[right], trial[left]
    return _position_allowed_for_answer(
        earliest, left, trial[left]
    ) and _position_allowed_for_answer(earliest, right, trial[right])


def enforce_answer_spread(steps: list[dict]) -> list[dict]:
    """Swap steps so no single answer dominates the lesson."""
    if len(steps) <= 2:
        return steps

    answers = [step.get("answerWordId") for step in steps if step.get("answerWordId")]
    if not answers:
        return steps

    earliest = _answer_first_intro_index(steps)
    unique_answers = len(set(answers))
    max_appearances = max(2, math.ceil(len(answers) / max(1, unique_answers)))
    result = list(steps)

    for _ in range(12):
        counts: Counter[str] = Counter()
        changed = False
        for index, step in enumerate(result):
            answer = step.get("answerWordId")
            if not answer:
                continue
            counts[answer] += 1
            if counts[answer] <= max_appearances:
                continue
            swap_idx = None
            for later in range(index + 1, len(result)):
                later_answer = result[later].get("answerWordId")
                if not later_answer or later_answer == answer:
                    continue
                if counts.get(later_answer, 0) >= max_appearances:
                    continue
                if not _swap_preserves_intro_order(earliest, index, later, result):
                    continue
                swap_idx = later
                break
            if swap_idx is None:
                continue
            result[index], result[swap_idx] = result[swap_idx], result[index]
            changed = True
            break
        if not changed:
            break

    return result


def enforce_min_answer_gap(steps: list[dict], min_gap: int = 3) -> list[dict]:
    """Swap graded steps so answer tokens do not repeat within min_gap positions."""
    if len(steps) <= min_gap:
        return steps

    earliest = _answer_first_intro_index(steps)
    result = list(steps)

    for _ in range(len(result) * 2):
        changed = False
        recent: list[frozenset[str]] = []
        for index, step in enumerate(result):
            if not _is_graded_exercise_step(step):
                continue
            if index > 0 and _allows_teach_intro_confirm_pair(result[index - 1], step):
                continue
            answers = frozenset(_step_graded_answer_ids(step))
            flat_recent = {token for group in recent for token in group}
            if answers and answers & flat_recent:
                swap_idx = None
                for later in range(index + 1, len(result)):
                    if not _is_graded_exercise_step(result[later]):
                        continue
                    later_answers = frozenset(_step_graded_answer_ids(result[later]))
                    if not later_answers or later_answers & flat_recent:
                        continue
                    if not _swap_preserves_intro_order(earliest, index, later, result):
                        continue
                    swap_idx = later
                    break
                if swap_idx is None:
                    recent = (recent + [answers])[-min_gap:]
                    continue
                result[index], result[swap_idx] = result[swap_idx], result[index]
                changed = True
                break
            recent = (recent + [answers])[-min_gap:]
        if not changed:
            break

    return result


def _trim_to_limit(steps: list[dict], limit: int) -> list[dict]:
    """Drop lowest-priority padding picks; keep rhythm-break steps."""
    if len(steps) <= limit:
        return steps
    result = list(steps)
    removable_kinds = frozenset({"watchChoose", "wordPickVideo", "translationChoose"})
    while len(result) > limit:
        drop_idx = None
        for idx in range(len(result) - 1, -1, -1):
            kind = result[idx].get("kind")
            if kind in PROTECTED_STEP_KINDS:
                continue
            if kind in removable_kinds:
                drop_idx = idx
                break
        if drop_idx is None:
            result.pop()
        else:
            result.pop(drop_idx)
    return result


def validate_lesson(
    steps: list[dict],
    taught_set: set[str],
    introduced_at_start: set[str] | None = None,
) -> None:
    last_kind: str | None = None
    last_teach_word: str | None = None
    introduced: set[str] = set(introduced_at_start or set())
    for step in steps:
        kind = step["kind"]
        if kind == "teach":
            wid = step.get("wordId")
            if last_kind == "teach":
                wid = step.get("wordId")
                allowed_cluster = False
                if wid and last_teach_word:
                    for phrase_id, comps in PHRASE_COMPONENTS.items():
                        cluster_words = set(comps) | {phrase_id}
                        if last_teach_word in cluster_words and wid in cluster_words:
                            allowed_cluster = True
                            break
                if not allowed_cluster:
                    raise ValueError("Adjacent teach steps in lesson")
            wid = step.get("wordId")
            if wid and wid not in taught_set:
                pass  # teach introduces word; taught_set grows during build
            last_teach_word = wid
            if wid:
                introduced.add(wid)
        elif kind == "signSequence":
            for wid in step.get("sequenceWordIds", []):
                if wid not in taught_set:
                    raise ValueError(f"Untaught signSequence slot: {wid}")
                introduced.add(wid)
            phrase = step.get("wordId")
            if phrase:
                introduced.add(phrase)
        elif kind == "matchPairs":
            for wid in step.get("pairWordIds", []):
                if wid not in introduced:
                    raise ValueError(f"Unintroduced matchPairs id: {wid}")
        else:
            answer = step.get("answerWordId")
            if answer and kind not in {"selfSign"}:
                if answer not in taught_set:
                    raise ValueError(f"Untaught answer {answer} in {kind}")
                if kind in QUIZ_KINDS and answer not in introduced:
                    if kind != "watchChoose":
                        raise ValueError(
                            f"{kind} for {answer} before new-sign introduction"
                        )
                if answer:
                    introduced.add(answer)
            word_id = step.get("wordId")
            if word_id and kind not in {"selfSign", "aslTip", "yourTurn"}:
                introduced.add(word_id)
        last_kind = kind

    for index in range(1, len(steps)):
        if not _pacing_ok(steps[:index], steps[index]):
            raise ValueError(
                f"Exercise pacing violation at index {index}: {steps[index].get('kind')}"
            )


def _apply_phrase_fill_spec(entry: dict, spec: dict[str, str]) -> None:
    phrase_id = spec["phraseWordId"]
    components = PHRASE_COMPONENTS.get(phrase_id, [])
    answer = entry.get("answerWordId")
    if answer not in components:
        return
    entry["wordId"] = phrase_id
    entry["sentenceBefore"] = spec.get("sentenceBefore", entry.get("sentenceBefore", ""))
    entry["sentenceAfter"] = spec.get("sentenceAfter", entry.get("sentenceAfter", ""))
    entry["prompt"] = spec.get("prompt", PHRASE_FILL_PROMPT)


def _valid_phrase_fill_entry(
    word: str,
    spec: dict[str, str],
    distractor_pool_words: list[str],
) -> dict | None:
    """Return a phrase-backed fillSlot payload, or None if validation fails."""
    phrase_id = spec.get("phraseWordId")
    if not phrase_id:
        return None
    components = PHRASE_COMPONENTS.get(phrase_id, [])
    if word not in components:
        return None
    entry: dict = {
        "sentenceBefore": spec.get("sentenceBefore", ""),
        "sentenceAfter": spec.get("sentenceAfter", ""),
        "answerWordId": word,
        "distractorWordIds": phrase_component_distractors(
            word,
            phrase_id,
            prefer_taught=set(distractor_pool_words),
            max_count=3,
        ),
        "wordId": phrase_id,
        "prompt": spec.get("prompt", PHRASE_FILL_PROMPT),
    }
    return entry


def _fill_dict_for(unit: dict) -> dict:
    specs = PHRASE_FILL_SLOTS.get(unit["id"], {})
    fill_by_word: dict[str, dict] = {}
    for word, spec in specs.items():
        if word not in unit["words"]:
            continue
        entry = _valid_phrase_fill_entry(word, spec, unit["words"])
        if entry:
            fill_by_word[word] = entry
    return fill_by_word


def _phrase_block_step_cost(builder: LessonBuilder, phrase_id: str) -> int:
    components = sign_sequence_components(phrase_id)
    teaches = sum(1 for comp in components if comp not in builder.state.ever_taught)
    if phrase_id not in builder.state.ever_taught:
        teaches += 1
    return teaches + 1


def _append_phrase_block(builder: LessonBuilder, phrase_id: str) -> None:
    """Teach components, phrase, then signSequence once per phrase across the path."""
    components = sign_sequence_components(phrase_id)
    if len(components) < 2:
        return
    if phrase_id in builder.state.sequenced_phrases:
        return
    if len(builder.steps) + _phrase_block_step_cost(builder, phrase_id) > builder._step_limit():
        return
    for comp in components:
        if comp in builder.state.ever_taught:
            continue
        if builder.stone == 3:
            if comp not in builder.state.taught_set:
                return
            continue
        builder.append_teach_block(comp)
    if builder.stone == 3 and phrase_id not in builder.state.ever_taught:
        return
    if len(builder.steps) + 1 > builder._step_limit():
        return
    if phrase_id not in builder.state.ever_taught:
        builder.append_teach_block(phrase_id)
    if builder.steps:
        last = builder.steps[-1]
        if (
            _phrase_video_exercise_id(last) == phrase_id
            or _graded_answer_id(last) == phrase_id
        ):
            builder._append_review_pad()
    builder.append(sign_sequence_step(phrase_id, components, builder.pool))
    builder.state.sequenced_phrases.add(phrase_id)


def _append_phrase_slot_review(builder: LessonBuilder, phrase_id: str) -> bool:
    """signSequence review for a phrase already built on a prior stone."""
    if phrase_id not in builder.state.sequenced_phrases:
        return False
    if any(
        step.get("kind") in {"signSequence", "phraseSlot"} and step.get("wordId") == phrase_id
        for step in builder.steps
    ):
        return False
    components = sign_sequence_components(phrase_id)
    if len(components) < 2:
        return False
    seq = sign_sequence_step(phrase_id, components, builder.pool)
    if len(builder.steps) + 1 > builder._step_limit():
        return False
    if builder.steps and _phrase_video_exercise_id(builder.steps[-1]) == phrase_id:
        if not builder._append_review_pad():
            return False
    builder.append(seq)
    return True


def _inject_phrase_slot_reviews(builder: LessonBuilder) -> None:
    """Stone 2–3: signSequence review for phrases learned on earlier stones."""
    if builder.stone not in (2, 3) or builder.unit["id"] not in PHRASE_SEQUENCE_UNITS:
        return
    new_stone_phrases: set[str] = set()
    if builder.stone == 3:
        new_stone_phrases = set(stone_phrase_ids(builder.unit["id"], 3))
    unit_phrases = [
        w
        for w in builder.unit["words"]
        if w in PHRASE_IDS
    ]
    for phrase_id in unit_phrases:
        if phrase_id in new_stone_phrases:
            continue
        if len(builder.steps) >= builder._step_limit() - 1:
            break
        _append_phrase_slot_review(builder, phrase_id)


def _phrase_blocks(builder: LessonBuilder, max_phrases: int = 2) -> None:
    unit_phrases = [w for w in builder.unit["words"] if w in PHRASE_IDS]
    for phrase_id in unit_phrases[:max_phrases]:
        if len(builder.steps) >= MAX_MODULE_STEPS - 6:
            break
        _append_phrase_block(builder, phrase_id)


def build_stone_steps(unit: dict, state: CurriculumState, stone: int) -> list[dict]:
    unit_for_stone = dict(unit)
    cumulative = cumulative_stone_words(unit["id"], stone)
    if cumulative is not None:
        unit_for_stone["words"] = cumulative
    prior_taught = set(state.taught_set)
    prior_ever = set(state.ever_taught)
    fill_by_word = _fill_dict_for(unit_for_stone)
    builder = LessonBuilder(
        unit_for_stone,
        state,
        fill_by_word,
        STONE_TEACH_META[stone],
        watch_reinforcement=1,
    )
    builder.compose_from_beats(stone)
    steps = builder.finish()
    lesson_taught = path_words_taught_in_lesson(steps)
    state.taught_set = prior_taught | lesson_taught
    state.ever_taught = prior_ever | lesson_taught
    return steps


def build_lesson(unit: dict, state: CurriculumState, stone: int) -> dict:
    lesson_key = f"l{stone}"
    lesson_words = cumulative_stone_words(unit["id"], stone) or unit["words"]
    steps, state.introduced_words = apply_prompt_framing(
        f"{unit['id']}-{lesson_key}",
        build_stone_steps(unit, state, stone),
        state.introduced_words,
        lesson_words,
    )
    if stone == 1:
        steps = pin_stone1_meaning_pick_prompts(steps)
    return module_lesson(
        unit,
        lesson_key,
        LESSON_TITLES[stone],
        stone,
        steps,
        display_title=stone_display_title(unit, stone),
        word_ids=lesson_words,
    )


def _global_phrase_fill_for(word: str, pool: list[str]) -> dict | None:
    """Look up a validated phrase-backed fillSlot entry for `word`."""
    for specs in PHRASE_FILL_SLOTS.values():
        if word not in specs:
            continue
        entry = _valid_phrase_fill_entry(word, specs[word], pool)
        if entry:
            return entry
    return None


def append_phrase_review_steps(
    steps: list[dict],
    phrase_id: str,
    pool: list[str],
    introduced: set[str],
    *,
    max_steps: int,
    unit_sort_order: int = 1,
    stone: int = 3,
) -> None:
    """Review-only phrase block: complete-the-phrase signSequence."""
    if len(steps) >= max_steps:
        return
    components = [
        c for c in sign_sequence_components(phrase_id) if c in introduced
    ]
    if len(components) < 2:
        return
    seq = sign_sequence_step(phrase_id, components, pool)
    if steps and _phrase_video_exercise_id(steps[-1]) == phrase_id:
        return
    steps.append(seq)


def review_lesson(unit: dict, state: CurriculumState) -> dict:
    """Phase checkpoint: a longer, phrase-forward recap over the whole phase.
    No new content — every item reviews already-taught vocabulary."""
    min_steps = CATEGORY_CHALLENGE_MIN_STEPS
    max_steps = CATEGORY_CHALLENGE_MAX_STEPS

    pool = distractor_pool(unit["words"], state.prior_pool)
    taught = [w for w in unit["words"] if w in state.taught_set]
    vocab = [w for w in taught if w not in PHRASE_IDS]
    phrases = [w for w in taught if w in PHRASE_IDS]
    if len(vocab) < 2:
        vocab = list(taught)

    steps: list[dict] = []

    # Open with variety before the phrase spotlight block.
    if len(vocab) >= 4:
        pair_count = min(4, len(vocab))
        pairs = vocab[:pair_count]
        steps.append(match_pairs_step(pairs))
    fill_added = 0
    fill_slot = 0
    while fill_added < 2 and fill_slot < len(vocab) and len(steps) < max_steps - 2:
        word = vocab[fill_slot % len(vocab)]
        fill_slot += 1
        entry = _global_phrase_fill_for(word, pool)
        if not entry:
            continue
        steps.append(fill_slot_step(entry))
        fill_added += 1

    # Phrase spotlight: complete-the-phrase signSequence reviews.
    opener_phrases = phrases[:MAX_PHRASE_OPENER]
    remaining_phrases = phrases[MAX_PHRASE_OPENER:]
    review_introduced = set(state.taught_set)
    for phrase_id in opener_phrases:
        append_phrase_review_steps(
            steps,
            phrase_id,
            pool,
            review_introduced,
            max_steps=max_steps,
            unit_sort_order=unit.get("sortOrder", 1),
            stone=3,
        )

    steps = dedupe_phrase_video_exercises(steps)
    steps = separate_adjacent_phrase_video_exercises(steps)
    if remaining_phrases:
        vocab = list(dict.fromkeys(vocab + remaining_phrases))

    # Whole-category vocab mix, cycling exercise types.
    vocab_kinds = ["watchChoose", "wordPickVideo", "translationChoose", "wordPickVideo", "fillSlot"]
    slot = 0
    your_turn_added = False
    while len(steps) < max_steps and vocab:
        word = vocab[slot % len(vocab)]
        kind = vocab_kinds[slot % len(vocab_kinds)]
        slot += 1

        if steps and _is_graded_exercise_step(steps[-1]):
            last_tokens = _graded_step_answer_tokens(steps[-1])
            if word in last_tokens:
                continue

        # Sprinkle a single Your Turn around the midpoint.
        if (not your_turn_added and len(steps) >= max(4, min_steps // 2)
                and len(steps) < max_steps - 2):
            steps.append(your_turn_step(word))
            your_turn_added = True
            continue

        if kind == "fillSlot":
            entry = _global_phrase_fill_for(word, pool)
            if entry:
                steps.append(fill_slot_step(entry))
                continue
            kind = "watchChoose"
        if kind == "matchPairs":
            count = min(4, max(2, len(vocab) // 2))
            start = slot % len(vocab)
            pairs = list(
                dict.fromkeys(vocab[(start + i) % len(vocab)] for i in range(count))
            )
            if len(pairs) >= 2:
                steps.append(match_pairs_step(pairs))
                continue
            kind = "watchChoose"
        if kind == "translationChoose":
            steps.append(translation_choose_step(word, pool, choice_count=4))
        elif kind == "wordPickVideo":
            steps.append(word_pick_video_step(word, pool))
        else:
            steps.append(watch_choose_step(word, pool, choice_count=2))

    # Guarantee the minimum length with extra recognition reps.
    pad = 0
    while len(steps) < min_steps and vocab:
        steps.append(watch_choose_step(vocab[pad % len(vocab)], pool, choice_count=2))
        pad += 1

    steps = steps[:max_steps]
    steps = enforce_variety(steps)
    steps = enforce_min_answer_gap(steps)
    steps = anchor_teach_confirm_pairs(steps)
    steps = enforce_max_teach_confirm_pairs(steps, pool)
    steps = dedupe_phrase_video_exercises(steps)
    steps = separate_adjacent_phrase_video_exercises(steps)
    steps = separate_adjacent_match_pairs(steps, pool)
    steps = enforce_no_adjacent_same_graded_answer(steps, pool)
    steps = enforce_step_pacing(steps, pool)
    try:
        validate_lesson(steps, state.taught_set, set(state.taught_set))
    except ValueError:
        pass
    lesson_id = f"{unit['id']}-review"
    steps, state.introduced_words = apply_prompt_framing(
        lesson_id, steps, state.introduced_words, unit["words"]
    )
    return module_lesson(unit, "review", "Checkpoint", 1, steps)


_CURRICULUM_STATE = CurriculumState()


def build_unit(unit: dict) -> dict:
    out = {
        "id": unit["id"],
        "title": unit["title"],
        "description": unit["description"],
        "badge": unit["badge"],
        "sortOrder": unit["sortOrder"],
        "phaseKey": unit["phaseKey"],
        "phaseTitle": unit["phaseTitle"],
    }
    if unit.get("isReview"):
        out["isReview"] = True
    if unit.get("isPhaseReview"):
        out["isPhaseReview"] = True
    if unit.get("mandatoryGateway"):
        out["mandatoryGateway"] = True
    if unit.get("isReview"):
        out["lessons"] = [review_lesson(unit, _CURRICULUM_STATE)]
    else:
        out["lessons"] = [
            build_lesson(unit, _CURRICULUM_STATE, 1),
            build_lesson(unit, _CURRICULUM_STATE, 2),
            build_lesson(unit, _CURRICULUM_STATE, 3),
        ]
        _CURRICULUM_STATE.register_unit(unit)
    return out


def phase_review_unit(phase_units: list[dict], sort_order: int) -> dict:
    """Phase recap — not a lesson unit; aggregates vocabulary from `phase_units`."""
    phase_key = phase_units[-1]["phaseKey"]
    phase_title = phase_units[-1]["phaseTitle"]
    seen: set[str] = set()
    words: list[str] = []
    for unit in phase_units:
        for word in unit["words"]:
            if word not in seen:
                seen.add(word)
                words.append(word)

    # Checkpoint pulls from the whole phase. Keep all phrases (phrase content is
    # the centerpiece) plus a generous vocab slice.
    phrase_words = [w for w in words if w in PHRASE_IDS]
    vocab_words = [w for w in words if w not in PHRASE_IDS]
    review_words = vocab_words[: min(24, len(vocab_words))] + phrase_words
    unit_titles = ", ".join(u["title"] for u in phase_units)
    checkpoint_badge = PHASE_CHECKPOINT_BADGES.get(phase_key, "Checkpoint")
    return {
        "id": f"p1-review-{phase_key}",
        "title": f"{phase_title} Checkpoint",
        "description": (
            f"Show what you remember from {phase_title} "
            f"({unit_titles})."
        ),
        "badge": checkpoint_badge,
        "sortOrder": sort_order,
        "phaseKey": phase_key,
        "phaseTitle": phase_title,
        "words": review_words,
        "isReview": True,
        "isPhaseReview": True,
    }


def expanded_units_with_reviews() -> list[dict]:
    """Insert a review immediately after each PHASE_SEGMENTS block."""
    ordered = ordered_units()
    segment_ends = {end for end, _, _ in PHASE_SEGMENTS}
    if max(segment_ends, default=0) != len(ordered):
        raise ValueError("PHASE_SEGMENTS must end at the final unit index")

    expanded: list[dict] = []
    sort_order = 1
    segment_start = 0

    for index, unit in enumerate(ordered):
        clone = dict(unit)
        clone["sortOrder"] = sort_order
        expanded.append(clone)
        sort_order += 1

        if (index + 1) in segment_ends:
            segment_units = ordered[segment_start : index + 1]
            expanded.append(phase_review_unit(segment_units, sort_order))
            sort_order += 1
            segment_start = index + 1

    return expanded



def export_curriculum_words_csv(units: list[dict], out_dir: Path) -> None:
    """Write curriculum-words-and-phrases.csv for filming tracker."""
    rows = ["id,display_name,type,primary_unit_id,primary_unit_title,unit_ids,unit_titles,unit_count,phrase_components"]
    unit_by_id = {u["id"]: u for u in units}
    word_units: dict[str, list[str]] = {}
    for unit in units:
        for word in unit["words"]:
            word_units.setdefault(word, []).append(unit["id"])

    all_ids = sorted(word_units.keys())
    for word_id in all_ids:
        unit_ids = word_units[word_id]
        primary_id = unit_ids[0]
        primary = unit_by_id[primary_id]
        display = DISPLAY_OVERRIDES.get(word_id, word_id.replace("_", " ").title())
        kind = "phrase" if word_id in PHRASE_IDS else "word"
        titles = ";".join(unit_by_id[uid]["title"] for uid in unit_ids)
        components = ";".join(PHRASE_COMPONENTS.get(word_id, []))
        rows.append(
            f'{word_id},{display},{kind},{primary_id},{primary["title"]},'
            f'{";".join(unit_ids)},{titles},{len(unit_ids)},{components}'
        )
    csv_path = out_dir / "curriculum-words-and-phrases.csv"
    csv_path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"Wrote {csv_path}")


def export_units_reference(units: list[dict], out_dir: Path) -> None:
    """Write units-and-words.md and .csv for curriculum reference."""
    lines = ["# Units and Words (curriculum v5)", "", "| # | Unit ID | Title | Words | Phrases |", "|---|---|---|---|---|"]
    csv_rows = ["index,unit_id,title,word_count,phrase_count,words"]
    for i, unit in enumerate(units, start=1):
        words = unit["words"]
        phrase_count = sum(1 for w in words if w in PHRASE_IDS)
        word_count = len(words) - phrase_count
        word_list = ", ".join(words)
        lines.append(f"| {i} | {unit['id']} | {unit['title']} | {word_count} | {phrase_count} |")
        csv_rows.append(f'{i},{unit["id"]},{unit["title"]},{word_count},{phrase_count},"{word_list}"')
        lines.append("")
        lines.append(f"### {i}. {unit['title']} (`{unit['id']}`)")
        lines.append("")
        lines.append(word_list)
        lines.append("")

    md_path = out_dir / "units-and-words.md"
    csv_path = out_dir / "units-and-words.csv"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    csv_path.write_text("\n".join(csv_rows) + "\n", encoding="utf-8")
    print(f"Wrote {md_path}")
    print(f"Wrote {csv_path}")


def export_curriculum_paths_units_words(
    data: dict,
    words_by_unit_id: dict[str, list[str]],
    out_dir: Path,
) -> None:
    """Master reference: path + every unit (incl. phase reviews) + each word/phrase."""
    version = data.get("version", "")
    words_lookup = words_by_unit_id

    def words_for_unit(unit: dict) -> list[str]:
        uid = unit["id"]
        if unit.get("isReview") or unit.get("isPhaseReview"):
            seen: set[str] = set()
            ordered: list[str] = []
            for lesson in unit.get("lessons", []):
                for word_id in lesson.get("wordIds", []):
                    if word_id not in seen:
                        seen.add(word_id)
                        ordered.append(word_id)
            return ordered
        return list(words_lookup.get(uid, []))

    detail_fields = [
        "curriculum_version",
        "path_id",
        "path_title",
        "path_tagline",
        "unit_sort_order",
        "unit_id",
        "unit_title",
        "unit_description",
        "unit_badge",
        "phase_key",
        "phase_title",
        "is_review",
        "is_phase_review",
        "lesson_count",
        "word_index",
        "word_id",
        "word_display_name",
        "word_type",
        "phrase_components",
    ]
    detail_rows: list[dict] = []
    for path in data.get("paths", []):
        for unit in path.get("units", []):
            base = {
                "curriculum_version": version,
                "path_id": path["id"],
                "path_title": path.get("title", ""),
                "path_tagline": path.get("tagline", ""),
                "unit_sort_order": unit.get("sortOrder", ""),
                "unit_id": unit["id"],
                "unit_title": unit.get("title", ""),
                "unit_description": unit.get("description", ""),
                "unit_badge": unit.get("badge", ""),
                "phase_key": unit.get("phaseKey", ""),
                "phase_title": unit.get("phaseTitle", ""),
                "is_review": unit.get("isReview", False),
                "is_phase_review": unit.get("isPhaseReview", False),
                "lesson_count": len(unit.get("lessons", [])),
            }
            words = words_for_unit(unit)
            if not words:
                detail_rows.append(
                    {
                        **base,
                        "word_index": "",
                        "word_id": "",
                        "word_display_name": "",
                        "word_type": "",
                        "phrase_components": "",
                    }
                )
                continue
            for index, word_id in enumerate(words, start=1):
                display = DISPLAY_OVERRIDES.get(
                    word_id, word_id.replace("_", " ").title()
                )
                kind = "phrase" if word_id in PHRASE_IDS else "word"
                detail_rows.append(
                    {
                        **base,
                        "word_index": index,
                        "word_id": word_id,
                        "word_display_name": display,
                        "word_type": kind,
                        "phrase_components": ";".join(
                            PHRASE_COMPONENTS.get(word_id, [])
                        ),
                    }
                )

    detail_path = out_dir / "curriculum-paths-units-words.csv"
    with detail_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=detail_fields)
        writer.writeheader()
        writer.writerows(detail_rows)

    summary_fields = [
        "curriculum_version",
        "path_id",
        "path_title",
        "unit_sort_order",
        "unit_id",
        "unit_title",
        "unit_description",
        "unit_badge",
        "phase_key",
        "phase_title",
        "is_review",
        "is_phase_review",
        "lesson_count",
        "word_count",
        "phrase_count",
        "words",
    ]
    summary_rows: list[dict] = []
    seen_unit_ids: set[str] = set()
    for row in detail_rows:
        unit_id = row["unit_id"]
        if unit_id in seen_unit_ids:
            continue
        seen_unit_ids.add(unit_id)
        unit_word_rows = [r for r in detail_rows if r["unit_id"] == unit_id and r["word_id"]]
        word_ids = [r["word_id"] for r in unit_word_rows]
        phrase_count = sum(1 for word_id in word_ids if word_id in PHRASE_IDS)
        summary_rows.append(
            {
                "curriculum_version": row["curriculum_version"],
                "path_id": row["path_id"],
                "path_title": row["path_title"],
                "unit_sort_order": row["unit_sort_order"],
                "unit_id": unit_id,
                "unit_title": row["unit_title"],
                "unit_description": row["unit_description"],
                "unit_badge": row["unit_badge"],
                "phase_key": row["phase_key"],
                "phase_title": row["phase_title"],
                "is_review": row["is_review"],
                "is_phase_review": row["is_phase_review"],
                "lesson_count": row["lesson_count"],
                "word_count": len(word_ids) - phrase_count,
                "phrase_count": phrase_count,
                "words": ", ".join(word_ids),
            }
        )

    summary_path = out_dir / "curriculum-paths-units-summary.csv"
    with summary_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=summary_fields)
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Wrote {detail_path}")
    print(f"Wrote {summary_path}")


def main() -> None:
    global _CURRICULUM_STATE
    _CURRICULUM_STATE = CurriculumState()
    ordered = ordered_units()
    _CURRICULUM_STATE.ordered_units = ordered
    export_units_reference(ordered, Path(__file__).parent)
    export_curriculum_words_csv(ordered, Path(__file__).parent)
    units_out = [build_unit(u) for u in expanded_units_with_reviews()]
    data = {
        "version": VERSION,
        "paths": [{
            "id": "path1",
            "title": "Learn ASL",
            "tagline": "Bite-sized units across every part of daily ASL.",
            "color": "#22C55E",
            "sortOrder": 1,
            "unlock": {"type": "always"},
            "units": units_out,
        }],
    }
    out_dir = Path(__file__).parent
    words_by_unit_id = {unit["id"]: unit["words"] for unit in UNITS}
    export_curriculum_paths_units_words(data, words_by_unit_id, out_dir)

    out = out_dir / "curriculum.json"
    out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8")
    total_lessons = sum(len(u["lessons"]) for u in units_out)
    modules = sum(1 for u in units_out for l in u["lessons"] if l["type"] == "module")
    steps = sum(len(l.get("steps", [])) for u in units_out for l in u["lessons"])
    def count_kind(kind: str) -> int:
        return sum(
            1
            for u in units_out
            for l in u["lessons"]
            for step in l.get("steps", [])
            if step["kind"] == kind
        )

    teach_steps = count_kind("teach")
    pick2_steps = count_kind("watchPick2")
    pick4_steps = count_kind("watchPick4")
    video_pick_steps = count_kind("wordPickVideo")
    same_diff_steps = count_kind("sameDifferent")
    meaning_steps = count_kind("meaningPick")
    watch_then_steps = count_kind("watchThenPick")
    watch_choose_steps = count_kind("watchChoose")
    translation_steps = count_kind("translationChoose")
    sign_sequence_steps = count_kind("signSequence")
    phrase_slot_steps = count_kind("phraseSlot")
    fill_slot_steps = count_kind("fillSlot")
    match_pair_steps = count_kind("matchPairs")
    fillgap_steps = count_kind("fillGap")
    self_sign_steps = count_kind("selfSign")
    print(f"Wrote {out}")
    print(f"  {len(units_out)} units, {total_lessons} lessons")
    print(f"  Module lessons: {modules}; total steps: {steps}")
    print(
        "  Mix: "
        f"teach={teach_steps} pick2={pick2_steps} pick4={pick4_steps} "
        f"wordPickVideo={video_pick_steps} sameDifferent={same_diff_steps} "
        f"meaningPick={meaning_steps} watchThenPick={watch_then_steps} "
        f"watchChoose={watch_choose_steps} translationChoose={translation_steps} "
        f"signSequence={sign_sequence_steps} phraseSlot={phrase_slot_steps} "
        f"fillSlot={fill_slot_steps} matchPairs={match_pair_steps} "
        f"fillGap={fillgap_steps} selfSign={self_sign_steps}"
    )
    _print_stone_mix_acceptance(data)


def _print_stone_mix_acceptance(data: dict) -> None:
    """Per-stone mix shares for retention rebalance acceptance checks."""
    graded_kinds = RECOGNITION_KINDS | {
        "translationChoose",
        "matchPairs",
        "signSequence",
        "phraseSlot",
        "fillSlot",
    }
    context_kinds = CONTEXT_STEP_KINDS
    print("  Stone mix (module lessons):")
    for stone in (1, 2, 3):
        counts: Counter[str] = Counter()
        for unit in data["paths"][0]["units"]:
            if unit.get("isReview") or unit.get("isPhaseReview"):
                continue
            for lesson in unit.get("lessons", []):
                if lesson.get("sortOrder") != stone or lesson.get("type") != "module":
                    continue
                for step in lesson.get("steps", []):
                    counts[step.get("kind", "?")] += 1
        total = sum(counts.values())
        if not total:
            continue
        graded = sum(counts[k] for k in graded_kinds if k in counts)
        recognition = sum(counts[k] for k in RECOGNITION_KINDS)
        rec_share = recognition / graded if graded else 0.0
        watch = counts.get("watchChoose", 0)
        pick = counts.get("wordPickVideo", 0)
        rec_total = watch + pick
        watch_pct = watch / rec_total * 100 if rec_total else 0.0
        pick_pct = pick / rec_total * 100 if rec_total else 0.0
        context = sum(counts[k] for k in context_kinds)
        cap = STONE_RECOGNITION_SHARE_CAP.get(stone, 0.65)
        print(
            f"    Stone {stone}: steps={total} recognition={rec_share:.0%} "
            f"(cap {cap:.0%}) watch/pick={watch_pct:.0f}/{pick_pct:.0f}% "
            f"yourTurn={counts.get('yourTurn', 0)} "
            f"match={counts.get('matchPairs', 0)} "
            f"translation={counts.get('translationChoose', 0)} "
            f"context={context}"
        )


if __name__ == "__main__":
    main()
