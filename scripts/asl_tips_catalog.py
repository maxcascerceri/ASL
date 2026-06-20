"""ASL Tip catalog — shared content for curriculum generation and the iOS app.

Each tip has a stable `id` so the client can track which tips the learner has seen.

Editorial standards (every tip must pass):
  1. Actionable — general ASL behavior, never app UX
  2. Friendly — warm Ziggy coach voice (you/your, normalize struggle)
  3. Sensible — plain language, no jargon, no contradictions with other tips
  4. Video-coherent — wordId is the best available sign illustration

Voice:
  - Second person: you / your
  - Prefer invitation over prohibition
  - No: wh-questions, negate, facial grammar, Deaf space, simcom, referents
  - No ALL CAPS sign names — use plain words (happy, today, give)

Structure:
  - ~110 characters max; one behavior; one sentence preferred
  - role (comment): listening | signing | both — who/when for face/eyes/nod tips

Video pairing:
  - Document rationale in category comments
  - DUPLICATE_WORDID_ALLOWLIST below permits shared wordIds when tips share a topic

DUPLICATE_WORDID_ALLOWLIST = frozenset({"fingerspell"})
"""

from __future__ import annotations

ASL_TIPS_CATALOG: list[dict[str, str]] = [
    # Face and expression
    # role=listening — watch their face while receiving signs
    {
        "id": "listen-watch-face",
        "text": "When someone's signing to you, watch their face — eyebrows and expression tell you a lot.",
        "wordId": "face",
    },
    # role=signing — match expression to meaning
    {
        "id": "sign-match-face",
        "text": "Let your face match what you're signing — a happy sign needs a happy face.",
        "wordId": "imhappy",
    },
    # role=signing — negation with headshake
    {
        "id": "sign-say-no",
        "text": "Saying no? Shake your head as you sign — your face and hands work together.",
        "wordId": "no",
    },
    # role=signing — skip English mouthing; translate video anchors language transfer
    {
        "id": "sign-no-mouthing",
        "text": "Skip mouthing the English word under your sign — your mouth is part of the sign.",
        "wordId": "translate",
    },
    # role=signing — keep face visible
    {
        "id": "sign-clear-face",
        "text": "Keep your hands off your mouth while signing so people can read your expression.",
        "wordId": "mouth",
    },
    # Hands and practice
    # role=signing — placement; body video anchors upper-body signing space
    {
        "id": "sign-zone",
        "text": "Keep signs in front of your chest — not down in your lap or up by your chin.",
        "wordId": "body",
    },
    # role=signing — dominant hand consistency
    {
        "id": "sign-one-hand",
        "text": "Stick with one signing hand — switching mid-sign makes you harder to follow.",
        "wordId": "practice",
    },
    # role=signing — slow practice; signslow video matches pacing idea
    {
        "id": "sign-slow-wins",
        "text": "Slow and clean beats fast and sloppy — speed comes once the sign feels natural.",
        "wordId": "signslow",
    },
    {
        "id": "sign-record-yourself",
        "text": "Record yourself and watch it back — you'll spot things you miss in the mirror.",
        "wordId": "camera",
    },
    {
        "id": "sign-location",
        "text": "Same handshape, different spot on your body — often a completely different word.",
        "wordId": "different",
    },
    # Fingerspelling (wordId fingerspell shared — allowlisted)
    {
        "id": "fs-steady-rhythm",
        "text": "Fingerspell in a steady rhythm — smooth flow beats racing through letters.",
        "wordId": "fingerspell",
    },
    {
        "id": "fs-lax-hand",
        "text": "Keep a relaxed hand — tension makes letters blur together.",
        "wordId": "fingerspell",
    },
    {
        "id": "fs-double-letters",
        "text": "Double letters? Slide or bounce slightly instead of holding the same shape twice.",
        "wordId": "letter",
    },
    {
        "id": "fs-locations",
        "text": "Keep fingerspelling near shoulder height in a small area — don't let it drift down.",
        "wordId": "fingerspell",
    },
    # Space and grammar
    {
        "id": "questions-eyebrows",
        "text": "Yes/no question? Raise your eyebrows. Who, what, or where? Lower them.",
        "wordId": "what",
    },
    {
        "id": "space-people",
        "text": "Place each person in a spot in space — then point back there for he, she, or they.",
        "wordId": "they",
    },
    {
        "id": "space-quote",
        "text": "Quoting someone? Turn toward them, sign their words, then turn back.",
        "wordId": "talk",
    },
    {
        "id": "space-direction",
        "text": "Signs like give and tell move toward whoever receives them — aim the action.",
        "wordId": "give",
    },
    {
        "id": "grammar-time-first",
        "text": "Words like today and tomorrow usually come first in the sentence.",
        "wordId": "today",
    },
    {
        "id": "grammar-finish-thought",
        "text": "Done with your thought? Hold the last sign, then lower your hands.",
        "wordId": "stop",
    },
    # Conversation and etiquette
    # role=both — getting attention; meet video anchors greeting/approach
    {
        "id": "meet-get-attention",
        "text": "Need someone's attention? Wave, tap their shoulder, or flick the lights.",
        "wordId": "meet",
    },
    # role=listening — turn-taking; wait video anchors pausing
    {
        "id": "meet-one-at-a-time",
        "text": "One person signs at a time — wait for a pause before you jump in.",
        "wordId": "wait",
    },
    {
        "id": "meet-rephrase",
        "text": "Sign didn't land? Try a different sign or shorter phrase — not just spelling faster.",
        "wordId": "howyousignthat",
    },
    {
        "id": "meet-sorry",
        "text": "Walked through two people signing? A quick sorry smooths it over.",
        "wordId": "excuseme",
    },
    {
        "id": "meet-two-hands",
        "text": "Set the coffee down — two free hands show the full sign.",
        "wordId": "tablet",
    },
    {
        "id": "meet-interpreter",
        "text": "With an interpreter, look at and talk to the Deaf person — not the interpreter.",
        "wordId": "interpreter",
    },
    # role=listening — tracking vs pretending (resolves nod contradiction)
    {
        "id": "listen-stay-with-them",
        "text": "While they sign, nod and stay engaged — it shows you're following along.",
        "wordId": "ok",
    },
    {
        "id": "listen-speak-up",
        "text": "Lost the thread? Ask again or show you're confused — pretending hurts both of you.",
        "wordId": "idontunderstand",
    },
    # role=signing — eye contact while producing signs
    {
        "id": "sign-look-at-them",
        "text": "When you sign, look at their face — not down at your own hands.",
        "wordId": "see",
    },
    # role=signing — lighting and framing merged
    {
        "id": "meet-on-camera",
        "text": "On video or in person, face the light and frame yourself chest-up with both hands visible.",
        "wordId": "video",
    },
    {
        "id": "sign-voice-or-hands",
        "text": "Pick signing or speaking — doing both at once is tough for others to follow.",
        "wordId": "signlanguage",
    },
]

DUPLICATE_WORDID_ALLOWLIST: frozenset[str] = frozenset({"fingerspell"})

ASL_TIPS_BY_ID: dict[str, dict[str, str]] = {tip["id"]: tip for tip in ASL_TIPS_CATALOG}


def tip_video_word_id(tip: dict[str, str]) -> str | None:
    """Return the catalog video wordId for a tip, if any."""
    return tip.get("wordId")


def alloc_asl_tip(used_ids: set[str], cursor: int) -> tuple[dict[str, str], int]:
    """Pick the next unused tip; advance cursor. Reuses only after the pool is exhausted."""
    catalog = ASL_TIPS_CATALOG
    if not catalog:
        raise ValueError("ASL_TIPS_CATALOG is empty")

    for offset in range(len(catalog)):
        index = (cursor + offset) % len(catalog)
        tip = catalog[index]
        if tip["id"] not in used_ids:
            used_ids.add(tip["id"])
            return tip, (index + 1) % len(catalog)

    index = cursor % len(catalog)
    return catalog[index], (index + 1) % len(catalog)
