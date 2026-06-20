"""Launch curriculum v5 unit definitions.

Each entry: (unit_id, title, description, badge, words_list)
`words_list` includes both vocabulary words and phrase video IDs.
Home-path order is the list order of UNIT_SPECS.
"""

from __future__ import annotations

# (id, title, description, badge, words)
UNIT_SPECS: list[tuple[str, str, str, str, list[str]]] = [
    # ── First Conversations (7) ──
    ("p1-u01", "Getting Started", "Your first signs, greetings, and introductions.", "Starter",
     ["hello", "thankyou", "bye", "please", "sorry", "welcome",
      "congratulations", "oops", "very", "much", "thankyouverymuch",
      "yourewelcome", "nice", "meet", "you", "how", "are", "my", "name",
      "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow"]),
    ("p1-u02", "Everyday Replies", "Yes, no, and everyday responses.", "Chatty",
     ["yes", "no", "ok", "sure", "really", "wow", "dontknow", "notyet", "samehere",
      "excuseme", "seeyoulater", "have", "havegoodday", "signagain", "nicetoseeyou", "alright",
      "cool", "awesome", "funny"]),
    ("p1-u03", "You & Me", "Pronouns and possessives.", "Subject",
     ["i", "you", "we", "he", "she", "they", "my", "your", "our", "his", "their"]),
    ("p1-u73", "Getting Help", "Ask for help, clarity, and safety.", "Survival",
     ["again", "wait", "need", "slow", "help", "understand",
      "idontunderstand", "ineedhelp", "canyouhelpme", "pleasehelpme",
      "little", "repeat", "that", "call", "nineoneone",
      "isignalittle", "canyourepeatthat", "pleasesignslower", "call911", "howyousignthat",
      "police", "emergency"]),
    ("p1-u06", "Feelings & Emotions", "How you feel and express personality.", "Mood",
     ["fine", "good", "great", "bad", "happy", "sad", "tired", "angry", "scared", "excited", "worry",
      "nervous", "imgood", "goodmorning", "goodnight",
      "imtired", "imhappy", "imsad", "imangry", "imscared", "imexcited", "imnervous",
      "bored", "lonely", "jealous", "embarrass", "frustrate", "surprise",
      "confident", "humble", "lazy", "stubborn", "curious", "serious", "remember", "forget"]),
    ("p1-u05", "Meet People", "Introductions, questions, and phrases.", "Introducer",
     ["person", "people", "myself", "yourself", "sign", "nice", "meet", "introduce",
      "what", "where", "when", "who", "why", "how", "which", "many",
      "whatisyourname", "whatsthat", "whatdoesthatmean", "howmany", "whereareyou",
      "from", "doing", "whereareyoufrom", "imfrom", "whatareyoudoing"]),
    ("p1-u22", "Deaf Culture", "ASL identity and the Deaf community.", "Linguist",
     ["deaf", "hearing", "hardofhearing", "asl", "signlanguage", "namesign", "deafculture",
      "fluent", "learnasl", "practice", "interpreter", "caption", "hearingaid", "lipread", "gesture",
      "translate", "whatisyournamesign", "imlearningasl"]),
    # ── Daily Life (7) ──
    ("p1-u24", "Everyday Actions", "Eat, move, give, and everyday verbs.", "Daily",
     ["eat", "drink", "see", "hear", "feel", "breathe", "smell", "want", "hungry",
      "make", "get", "give", "take", "use", "find", "try", "doing",
      "tell", "ask", "talk", "think", "know", "believe",
      "iwanteat", "iwantdrink", "imhungry", "iwant"]),
    ("p1-u23", "On the Move", "Go, move, and directions.", "Mover",
     ["go", "come", "walk", "run", "stop", "turn", "move", "lost", "imlost",
      "here", "there", "left", "right", "up", "down", "near", "far"]),
    ("p1-u56", "Getting There", "Commute, traffic, and vehicles.", "Commuter",
     ["drive", "ride", "arrive", "travel", "road", "street", "traffic", "commute",
      "car", "bus", "train", "airplane", "bike", "truck", "motorcycle", "boat"]),
    ("p1-u40", "Time & Calendar", "Today, weekdays, and clock time.", "Scheduler",
     ["today", "tomorrow", "now", "morning", "afternoon", "night",
      "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
      "weekend", "holiday", "yesterday", "noon",
      "day", "week", "month", "year", "hour", "minute", "later", "early"]),
    ("p1-u18", "Family & People", "Family, relatives, and people types.", "Family",
     ["mother", "father", "sister", "brother", "baby", "child", "family", "parents",
      "grandmother", "grandfather", "aunt", "uncle", "cousin", "niece", "nephew", "twins",
      "man", "woman", "boy", "girl", "adult", "teenager"]),
    ("p1-u49", "Friends & Holidays", "Friends, love, and celebrations.", "Social",
     ["love", "like", "hate", "friend", "hug", "kiss", "ilike",
      "party", "birthday", "christmas", "halloween", "thanksgiving", "easter"]),
    ("p1-u30", "My Home", "Rooms and spaces where you live.", "Homemaker",
     ["home", "house", "kitchen", "bathroom", "bedroom", "livingroom", "basement", "backyard",
      "wherebathroom", "garage"]),
    # ── Home & Foundations (8) ──
    ("p1-u31", "Furniture", "Tables, chairs, beds, and more.", "Decorator",
     ["table", "chair", "bed", "couch", "door", "window", "lamp", "clock"]),
    ("p1-u17", "Money & Counting", "Pay, price, and number math.", "Money",
     ["money", "pay", "cost", "price", "1dollar", "5dollars",
      "half", "quarter", "percent", "double", "triple", "hundred"]),
    ("p1-u57", "School & Classroom", "School life, subjects, and tools.", "Scholar",
     ["school", "class", "student", "teacher", "learn", "study", "read", "write",
      "math", "science", "history", "art", "book", "pen", "paper"]),
    ("p1-u45", "Health & Town", "Wellness and places in your community.", "Wellness",
     ["health", "exercise", "doctor", "nurse", "hospital", "medicine",
      "shop", "park", "restaurant", "hotel", "library", "church"]),
    ("p1-u15", "Numbers", "Zero through eleven.", "Counter",
     ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]),
    ("p1-u10", "The Alphabet", "Fingerspell A through Z.", "Speller",
     ["alphabet", "fingerspell", "letter",
      "a", "b", "c", "d", "e", "f", "g", "h", "letteri", "j", "k", "l", "m", "n",
      "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]),
    ("p1-u32", "At Home", "Morning routine, chores, and sleep.", "Fresh",
     ["shower", "toilet", "sink", "soap", "toothbrush", "brush", "comb", "mirror",
      "clean", "wash", "sweep", "vacuum", "washdishes", "sleep"]),
    ("p1-u27", "Colors", "Every color and shade.", "Colorist",
     ["red", "blue", "green", "yellow", "orangecolor", "purple", "pink", "brown",
      "black", "white", "gray", "gold", "silver", "dark", "light", "bright"]),
    # ── Describe & Express (7) ──
    ("p1-u29", "Size & Amount", "Big, small, and how much.", "Descriptor",
     ["big", "small", "tall", "hot", "cold", "fast", "hard",
      "almost", "many", "few", "enough", "more", "less"]),
    ("p1-u08", "Connect Ideas", "And, but, because, and more.", "Connector",
     ["and", "but", "or", "so", "with", "without", "also", "because", "same", "different", "if",
      "language", "word"]),
    ("p1-u42", "Body & Wellness", "Body parts and feeling sick.", "Face",
     ["head", "face", "eyes", "ear", "nose", "mouth", "teeth", "tongue",
      "body", "arm", "hands", "finger", "shoulder", "neck", "back", "stomach",
      "sick", "hurt", "pain", "headache", "cough", "sneeze", "dizzy"]),
    ("p1-u50", "Clothes & Accessories", "Outfits, jewelry, and what you carry.", "Daily Wear",
     ["shirt", "pants", "dress", "shoes", "socks", "jacket", "hat", "clothes",
      "shorts", "skirt", "sweater", "boots", "gloves", "scarf", "belt", "suit",
      "glasses", "earring", "necklace", "bracelet", "ring", "backpack", "wallet", "watch"]),
    ("p1-u59", "Work Life", "Jobs, bosses, and careers.", "Worker",
     ["work", "job", "boss", "lawyer", "engineer", "scientist", "meeting", "retire"]),
    ("p1-u69", "Devices & Apps", "Phones, screens, and the internet.", "Techie",
     ["computer", "phone", "tablet", "laptop", "camera", "tv", "keyboard", "mouse",
      "internet", "email", "text", "download", "upload", "share", "send", "video"]),
    ("p1-u68", "Countries", "Places around the world.", "Global",
     ["america", "canada", "mexico", "france", "germany", "china", "japan", "italy"]),
    # ── Life & Fluency (8) ──
    ("p1-u60", "Animals", "Pets, farm, and wild animals.", "Pet Friend",
     ["dog", "cat", "horse", "cow", "pig", "sheep", "rabbit", "duck",
      "lion", "tiger", "elephant", "bear", "wolf", "fox", "eagle", "monkey"]),
    ("p1-u63", "Weather", "Rain, snow, wind, and storms.", "Forecaster",
     ["rain", "snow", "wind", "cloud", "lightning", "thunder", "hot", "cold"]),
    ("p1-u62", "Nature & Seasons", "Outdoors through the year.", "Outdoors",
     ["tree", "flower", "mountain", "river", "ocean", "beach", "sun", "moon",
      "spring", "summer", "fall", "winter"]),
    ("p1-u65", "Sports", "Team and solo sports.", "Sporty",
     ["football", "basketball", "baseball", "soccer", "volleyball", "hockey", "tennis", "golf"]),
    ("p1-u66", "Music & Art", "Draw, sing, dance, and play.", "Creative",
     ["draw", "paint", "sing", "dance", "music", "guitar", "piano"]),
    ("p1-u35", "Fruits & Veggies", "Produce basics.", "Fruity",
     ["apple", "banana", "orangefruit", "grapes", "strawberry", "cherry", "pineapple", "lemon",
      "tomato", "carrot", "corn", "onion", "potato", "lettuce"]),
    ("p1-u37", "Food & Drinks", "Meals, snacks, drinks, and cooking.", "Protein",
     ["meat", "fish", "egg", "cheese", "milk", "butter", "bacon", "chicken",
      "bread", "pizza", "cake", "chocolate", "water", "coffee", "tea", "juice", "thirsty", "imthirsty",
      "breakfast", "lunch", "dinner", "full", "delicious", "cook"]),
    ("p1-u71", "Everyday Sayings", "Common ASL expressions and big ideas.", "Thinker",
     ["can", "cannot", "maybe", "important", "rightcorrect", "wrong", "future", "always",
      "onemoretime", "nevermind", "letmesee", "talktoyoulater",
      "giveup", "blowmind", "allofsudden", "wrapup", "letgo"]),
]

UNIT_ORDER_BY_TITLE: list[str] = [spec[1] for spec in UNIT_SPECS]

# Per-stone vocabulary subsets — manual overrides (auto-filled to 3 stones at import).
MANUAL_UNIT_STONE_WORD_SUBSETS: dict[str, list[list[str]]] = {
    "p1-u01": [
        ["hello", "thankyou", "bye", "please", "sorry", "welcome", "congratulations", "oops", "very", "much"],
        ["thankyouverymuch", "yourewelcome", "nice", "meet", "you", "my", "name", "how", "are",
         "mynameis", "nicetomeetyou", "howareyou"],
        ["imfine", "signslow"],
    ],
    "p1-u06": [
        ["fine", "good", "bad", "happy", "sad", "great"],
        ["angry", "tired", "scared", "imtired", "imscared", "imgood", "imhappy", "imsad", "imangry",
         "excited", "worry", "nervous", "imexcited", "imnervous", "goodmorning", "goodnight"],
        ["bored", "lonely", "jealous", "embarrass", "frustrate", "surprise",
         "confident", "humble", "lazy", "stubborn", "curious", "serious", "remember", "forget"],
    ],
    "p1-u10": [
        ["alphabet", "fingerspell", "letter", "a", "b", "c", "d", "e", "f", "g"],
        ["h", "letteri", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t"],
        ["u", "v", "w", "x", "y", "z"],
    ],
    "p1-u24": [
        ["eat", "drink", "see", "hear", "feel", "breathe", "smell"],
        ["want", "hungry", "make", "get", "give", "take",
         "iwanteat", "iwantdrink", "imhungry", "use", "find", "try", "doing"],
        ["iwant", "tell", "ask", "talk", "think", "know", "believe"],
    ],
    "p1-u40": [
        ["today", "tomorrow", "now", "morning", "afternoon", "night"],
        ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
         "sunday", "weekend", "holiday", "yesterday", "noon", "day"],
        ["week", "month", "year", "hour", "minute", "later", "early"],
    ],
    "p1-u50": [
        ["shirt", "pants", "shoes", "dress", "jacket", "hat"],
        ["socks", "clothes", "shorts", "skirt", "sweater", "boots",
         "gloves", "scarf", "belt", "suit", "glasses", "watch"],
        ["earring", "necklace", "bracelet", "ring", "backpack", "wallet"],
    ],
    "p1-u73": [
        ["again", "wait", "need", "slow"],
        ["help", "understand", "idontunderstand", "ineedhelp", "little", "isignalittle", "repeat", "that",
         "canyourepeatthat", "please", "me", "canyouhelpme", "pleasehelpme", "pleasesignslower",
         "howyousignthat", "police", "emergency"],
        ["call", "nineoneone", "call911"],
    ],
    "p1-u05": [
        ["person", "people", "myself", "yourself", "sign", "nice", "meet", "introduce"],
        ["what", "where", "when", "who", "why", "how", "which", "many",
         "whatisyourname", "whatsthat", "whatdoesthatmean"],
        ["howmany", "whereareyou", "from", "doing", "whereareyoufrom", "imfrom", "whatareyoudoing"],
    ],
    "p1-u22": [
        ["deaf", "hearing", "hardofhearing", "asl", "signlanguage"],
        ["namesign", "deafculture", "fluent", "learnasl", "practice",
         "whatisyournamesign", "imlearningasl"],
        ["interpreter", "caption", "hearingaid", "lipread", "gesture", "translate"],
    ],
    "p1-u02": [
        ["yes", "no", "ok", "sure", "really", "wow", "dontknow", "notyet", "signagain", "cool"],
        ["awesome", "funny", "samehere", "excuseme", "seeyoulater"],
        ["have", "havegoodday", "nicetoseeyou", "alright"],
    ],
    "p1-u03": [
        ["i", "you", "we", "my", "your"],
        ["he", "she", "they", "his", "their", "our"],
        [],
    ],
    "p1-u23": [
        ["go", "come", "walk", "run"],
        ["stop", "turn", "move", "lost", "imlost", "here", "there", "left", "right", "up", "down", "near", "far"],
        [],
    ],
    "p1-u49": [
        ["love", "like", "hate", "friend", "hug", "kiss", "ilike"],
        ["party", "birthday", "christmas", "halloween", "thanksgiving", "easter"],
        [],
    ],
    "p1-u30": [
        ["home", "house", "kitchen", "bathroom"],
        ["bedroom", "livingroom", "basement", "backyard", "garage", "where", "wherebathroom"],
        [],
    ],
    "p1-u37": [
        ["meat", "fish", "egg", "cheese", "milk", "butter", "bacon", "chicken"],
        ["bread", "pizza", "cake", "chocolate", "breakfast", "lunch", "dinner", "full", "delicious", "cook",
         "water", "coffee", "tea", "juice", "thirsty", "imthirsty"],
        [],
    ],
}

# Units that emit signSequence phrase blocks on stones 2–3.
PHRASE_SEQUENCE_UNITS: set[str] = {
    "p1-u01", "p1-u02", "p1-u73", "p1-u06", "p1-u05", "p1-u22", "p1-u24",
    "p1-u23", "p1-u49", "p1-u30", "p1-u37", "p1-u71",
}

UNIT_STONE_DISPLAY_OVERRIDES: dict[str, list[str]] = {
    "p1-u01": [
        "Getting Started",
        "Introduce Yourself",
        "Getting Started Challenge",
    ],
    "p1-u03": [
        "You & Me",
        "Pronouns in Action",
        "Pronoun Challenge",
    ],
    "p1-u02": [
        "Everyday Replies",
        "Answer Naturally",
        "Response Challenge",
    ],
    "p1-u73": [
        "Ask for Help",
        "Fix Confusion",
        "Emergency Help",
    ],
    "p1-u06": [
        "How You Feel",
        "More Feelings",
        "Personality Challenge",
    ],
    "p1-u05": [
        "Meet People",
        "What's Your Name",
        "Question Challenge",
    ],
    "p1-u49": [
        "Friends and Love",
        "Holiday Signs",
        "Social Challenge",
    ],
    "p1-u10": [
        "Fingerspelling Basics",
        "Letters A–T",
        "Letters U–Z Challenge",
    ],
    "p1-u24": [
        "Daily Actions",
        "Meals & Doing",
        "Think & Communicate",
    ],
    "p1-u40": [
        "Right Now",
        "Weekend & Holidays",
        "Clock & Calendar Challenge",
    ],
    "p1-u50": [
        "Everyday Wear",
        "Outerwear & Glasses",
        "Jewelry & Gear Challenge",
    ],
    "p1-u22": [
        "Deaf Culture",
        "Community Signs",
        "Culture Challenge",
    ],
    "p1-u71": [
        "Big Ideas",
        "Use in Context",
        "Expression Challenge",
    ],
}

GENERIC_STONE_TITLES: list[str] = [
    "Learn & Lock In",
    "Use It",
    "Challenge",
]


def stone_display_title(unit: dict, stone: int) -> str:
    """User-facing stone label; falls back to generic internal titles."""
    overrides = UNIT_STONE_DISPLAY_OVERRIDES.get(unit["id"])
    if overrides and 1 <= stone <= len(overrides):
        return overrides[stone - 1]

    unit_title = unit["title"]
    if stone == 1:
        return unit_title
    if stone == 2:
        return f"{unit_title}: Use It"
    if stone == 3:
        return f"{unit_title} Challenge"

    return GENERIC_STONE_TITLES[stone - 1] if 1 <= stone <= len(GENERIC_STONE_TITLES) else unit_title


PHASE_SEGMENTS: list[tuple[int, str, str]] = [
    (7, "first_conversations", "First Conversations"),
    (14, "daily_life", "Daily Life"),
    (22, "home_and_foundations", "Home & Foundations"),
    (29, "describe_and_express", "Describe & Express"),
    (37, "life_and_fluency", "Life & Fluency"),
]

PHASE_CHECKPOINT_BADGES: dict[str, str] = {
    "first_conversations": "Conversation Checkpoint",
    "daily_life": "Daily Life Checkpoint",
    "home_and_foundations": "Foundations Checkpoint",
    "describe_and_express": "Expression Checkpoint",
    "life_and_fluency": "Fluency Checkpoint",
}

PHRASE_IDS: set[str] = {
    "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow", "yourewelcome",
    "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere", "havegoodday",
    "whatisyourname", "whatsthat", "whatdoesthatmean", "imgood", "goodmorning", "goodnight",
    "idontunderstand", "ineedhelp", "canyouhelpme", "pleasehelpme",
    "wherebathroom", "nicetoseeyou", "letmesee", "howyousignthat", "onemoretime", "talktoyoulater",
    "blowmind", "allofsudden", "wrapup", "letgo",
    "imtired", "imhappy", "imsad", "imangry", "imscared",
    "iwant", "ilike", "imhungry", "iwanteat", "iwantdrink",
    "howmany", "whereareyou",
    "whatisyournamesign", "imlearningasl",
    "isignalittle", "canyourepeatthat", "pleasesignslower", "thankyouverymuch",
    "whereareyoufrom", "imfrom", "whatareyoudoing", "imexcited", "imnervous",
    "imthirsty", "call911", "imlost",
}

PHRASE_COMPONENTS: dict[str, list[str]] = {
    "mynameis": ["my", "name"],
    "nicetomeetyou": ["nice", "meet", "you"],
    "howareyou": ["how", "are", "you"],
    "imfine": ["i", "fine"],
    "signslow": ["sign", "slow"],
    "yourewelcome": ["your", "welcome"],
    "dontknow": ["i", "know"],
    "notyet": ["no", "notyet"],
    "signagain": ["sign", "again"],
    "excuseme": ["excuseme"],
    "seeyoulater": ["see", "you", "later"],
    "samehere": ["same", "here"],
    "havegoodday": ["have", "a", "good", "day"],
    "whatisyourname": ["what", "your", "name"],
    "whatsthat": ["what", "that"],
    "whatdoesthatmean": ["what", "that"],
    "imgood": ["i", "good"],
    "goodmorning": ["good", "morning"],
    "goodnight": ["good", "night"],
    "idontunderstand": ["i", "understand"],
    "ineedhelp": ["i", "need", "help"],
    "canyouhelpme": ["you", "help", "me"],
    "pleasehelpme": ["please", "help", "me"],
    "wherebathroom": ["where", "bathroom"],
    "nicetoseeyou": ["nice", "see", "you"],
    "letmesee": ["me", "see", "letmesee"],
    "howyousignthat": ["how", "you", "sign"],
    "onemoretime": ["one", "more", "again"],
    "talktoyoulater": ["talk", "you", "later"],
    "blowmind": ["wow", "really"],
    "allofsudden": ["wow", "really"],
    "wrapup": ["bye", "thankyou"],
    "letgo": ["go", "letgo"],
    "imtired": ["i", "tired"],
    "imhappy": ["i", "happy"],
    "imsad": ["i", "sad"],
    "imangry": ["i", "angry"],
    "imscared": ["i", "scared"],
    "iwant": ["i", "want"],
    "ilike": ["i", "like"],
    "imhungry": ["i", "hungry"],
    "iwanteat": ["i", "want", "eat"],
    "iwantdrink": ["i", "want", "drink"],
    "howmany": ["how", "many"],
    "whereareyou": ["where", "you"],
    "whatisyournamesign": ["what", "your", "namesign"],
    "imlearningasl": ["i", "learnasl"],
    "isignalittle": ["i", "sign", "little"],
    "canyourepeatthat": ["you", "repeat", "that"],
    "pleasesignslower": ["please", "sign", "slow"],
    "thankyouverymuch": ["thankyou", "very", "much"],
    "whereareyoufrom": ["where", "you", "from"],
    "imfrom": ["i", "from"],
    "whatareyoudoing": ["what", "you", "doing"],
    "imexcited": ["i", "excited"],
    "imnervous": ["i", "nervous"],
    "imthirsty": ["i", "thirsty"],
    "call911": ["call", "nineoneone"],
    "imlost": ["i", "lost"],
}

PHRASE_FILL_PROMPT = "Watch the phrase. Which sign is missing?"

# unit_id -> answer_word_id -> phrase-backed fillSlot spec (merged at generation time).
# Only entries whose phraseWordId is filmed and whose answer is a phrase component
# are emitted. Pending filming (do not add until phrase clip exists):
#   pleasehelpme, wrapup, pleasesignslower, iwanteat
# unit_id -> trigger_word_id -> phrase_id for early complete-the-phrase previews.
PHRASE_CONTEXT_SIGN_SEQUENCES: dict[str, dict[str, str]] = {
    "p1-u01": {
        "welcome": "yourewelcome",
    },
}

PHRASE_FILL_SLOTS: dict[str, dict[str, dict[str, str]]] = {
    "p1-u01": {
        "my": {
            "phraseWordId": "mynameis",
            "sentenceBefore": "",
            "sentenceAfter": " name is…",
        },
    },
    "p1-u02": {
        "wow": {
            "phraseWordId": "blowmind",
            "sentenceBefore": "",
            "sentenceAfter": ", blown away",
        },
    },
    "p1-u03": {
        "my": {
            "phraseWordId": "mynameis",
            "sentenceBefore": "",
            "sentenceAfter": " name is…",
        },
        "your": {
            "phraseWordId": "whatisyourname",
            "sentenceBefore": "What's ",
            "sentenceAfter": " name?",
        },
    },
    "p1-u73": {
        "again": {
            "phraseWordId": "onemoretime",
            "sentenceBefore": "",
            "sentenceAfter": " more time",
        },
    },
    "p1-u05": {
        "where": {
            "phraseWordId": "wherebathroom",
            "sentenceBefore": "",
            "sentenceAfter": " is the bathroom?",
        },
    },
    "p1-u24": {
        "see": {
            "phraseWordId": "letmesee",
            "sentenceBefore": "Let me ",
            "sentenceAfter": "",
        },
        "talk": {
            "phraseWordId": "talktoyoulater",
            "sentenceBefore": "",
            "sentenceAfter": " to you later",
        },
    },
    "p1-u23": {
        "go": {
            "phraseWordId": "letgo",
            "sentenceBefore": "Time to ",
            "sentenceAfter": "",
        },
    },
    "p1-u40": {
        "later": {
            "phraseWordId": "talktoyoulater",
            "sentenceBefore": "Talk to you ",
            "sentenceAfter": "",
        },
    },
    "p1-u15": {
        "one": {
            "phraseWordId": "onemoretime",
            "sentenceBefore": "",
            "sentenceAfter": " more time",
        },
    },
    "p1-u29": {
        "more": {
            "phraseWordId": "onemoretime",
            "sentenceBefore": "One ",
            "sentenceAfter": " time",
        },
    },
}

DISPLAY_OVERRIDES: dict[str, str] = {
    "1dollar": "1 Dollar",
    "5dollars": "5 Dollars",
    "allofsudden": "All Of A Sudden",
    "america": "America / USA",
    "are": "Are",
    "asl": "ASL",
    "awesome": "Awesome",
    "blowmind": "Blow Mind",
    "call911": "Call 911",
    "canyouhelpme": "Can You Help Me",
    "canyourepeatthat": "Can You Repeat That?",
    "deafculture": "Deaf Culture",
    "doing": "Doing",
    "dontknow": "Don't Know",
    "call": "Call",
    "cool": "Cool",
    "emergency": "Emergency",
    "excuseme": "Excuse Me",
    "fluent": "Fluent",
    "from": "From",
    "funny": "Funny",
    "giveup": "Give Up",
    "goodmorning": "Good Morning",
    "goodnight": "Good Night",
    "hardofhearing": "Hard Of Hearing",
    "have": "Have",
    "havegoodday": "Have A Good Day",
    "hearingaid": "Hearing Aid",
    "howareyou": "How Are You",
    "howmany": "How Many?",
    "howyousignthat": "How Do You Sign That",
    "idontunderstand": "I Don't Understand",
    "imfine": "I'm Fine",
    "imexcited": "I'm Excited",
    "imfrom": "I'm From ___",
    "imhappy": "I'm Happy",
    "imhungry": "I'm Hungry",
    "imangry": "I'm Angry",
    "imgood": "I'm Good",
    "imlearningasl": "I'm Learning ASL",
    "imlost": "I'm Lost",
    "imnervous": "I'm Nervous",
    "imsad": "I'm Sad",
    "imscared": "I'm Scared",
    "imtired": "I'm Tired",
    "imthirsty": "I'm Thirsty",
    "ilike": "I Like",
    "ineedhelp": "I Need Help",
    "isignalittle": "I Sign A Little",
    "iwant": "I Want",
    "iwantdrink": "I Want To Drink",
    "iwanteat": "I Want To Eat",
    "learnasl": "Learn ASL",
    "letteri": "Letter I",
    "letgo": "Let Go",
    "letmesee": "Let Me See",
    "little": "Little",
    "livingroom": "Living Room",
    "lost": "Lost",
    "mexico": "Mexico",
    "much": "Much",
    "mynameis": "My Name Is",
    "namesign": "Name Sign",
    "nervous": "Nervous",
    "nevermind": "Never Mind",
    "nicetomeetyou": "Nice To Meet You",
    "nicetoseeyou": "Nice To See You",
    "nineoneone": "911",
    "notyet": "Not Yet",
    "onemoretime": "One More Time",
    "orangecolor": "Orange Color",
    "orangefruit": "Orange Fruit",
    "pleasehelpme": "Please Help Me",
    "pleasesignslower": "Please Sign Slower",
    "police": "Police",
    "practice": "Practice",
    "rightcorrect": "Right / Correct",
    "repeat": "Repeat",
    "samehere": "Same Here",
    "seeyoulater": "See You Later",
    "signagain": "Sign Again",
    "signlanguage": "Sign Language",
    "signslow": "Sign Slow",
    "talktoyoulater": "Talk To You Later",
    "thankyou": "Thank You",
    "thankyouverymuch": "Thank You Very Much",
    "that": "That",
    "thirsty": "Thirsty",
    "try": "Try",
    "washdishes": "Wash Dishes",
    "whatdoesthatmean": "What Does That Mean",
    "whatareyoudoing": "What Are You Doing?",
    "whatisyourname": "What's Your Name",
    "whatisyournamesign": "What's Your Name Sign?",
    "whatsthat": "What's That",
    "whereareyou": "Where Are You?",
    "whereareyoufrom": "Where Are You From?",
    "wherebathroom": "Where Is The Bathroom",
    "wrapup": "Wrap Up",
    "yourewelcome": "You're Welcome",
}

SENTENCE_OVERRIDES: dict[str, dict[str, tuple[str, str]]] = {
    "p1-u01": {
        "hello": ("", ", nice to meet you."),
        "bye": ("", " for now!"),
        "please": ("", ", one moment."),
        "thankyou": ("", " so much!"),
        "sorry": ("", ", my mistake."),
        "welcome": ("You're ", " here."),
        "thankyouverymuch": ("", ", friend!"),
        "name": ("My ", " is Max."),
        "mynameis": ("", " — fingerspell name."),
        "nicetomeetyou": ("", ", friend!"),
        "howareyou": ("", " today?"),
        "imfine": ("I am ", ", thanks."),
        "signslow": ("", ", please."),
        "yourewelcome": ("", ", anytime."),
    },
    "p1-u02": {
        "yes": ("", ", I agree."),
        "no": ("", ", not today."),
        "ok": ("", ", sounds good."),
        "sure": ("", ", count me in."),
        "wow": ("", ", that's amazing!"),
        "really": ("", "? Tell me more."),
        "alright": ("", ", let's begin."),
        "dontknow": ("I ", " yet."),
        "notyet": ("Done? ", "."),
        "signagain": ("", ", please."),
        "excuseme": ("", ", one moment."),
        "seeyoulater": ("", ", friend!"),
        "samehere": ("", ", me too."),
        "havegoodday": ("", ", friend!"),
        "cool": ("That's ", "."),
        "awesome": ("That is ", "!"),
        "funny": ("That is ", "."),
    },
    "p1-u73": {
        "again": ("", ", please."),
        "wait": ("", " for me."),
        "need": ("I ", " help."),
        "slow": ("Sign ", ", please."),
        "help": ("I ", " now."),
        "understand": ("I ", " now."),
        "idontunderstand": ("", ", repeat please."),
        "ineedhelp": ("", " now."),
        "canyouhelpme": ("", " please?"),
        "pleasehelpme": ("", " please?"),
        "isignalittle": ("", ", still learning."),
        "canyourepeatthat": ("", " please?"),
        "pleasesignslower": ("", ", please."),
        "call911": ("", " now!"),
        "howyousignthat": ("", "?"),
    },
    "p1-u06": {
        "imtired": ("I am ", "."),
        "imhappy": ("I am ", " today."),
        "imsad": ("I am ", " now."),
        "imangry": ("I am ", "."),
        "imscared": ("I am ", "."),
        "imexcited": ("I am ", "!"),
        "imnervous": ("I am ", "."),
    },
    "p1-u22": {
        "deaf": ("I am ", "."),
        "asl": ("I learn ", "."),
        "whatisyournamesign": ("", "?"),
        "imlearningasl": ("", " every day."),
        "practice": ("", " every day."),
        "isignalittle": ("", ", still learning."),
    },
    "p1-u24": {
        "iwanteat": ("", " now."),
        "iwantdrink": ("", " please."),
        "smell": ("I can ", " flowers."),
        "try": ("", " again."),
    },
    "p1-u08": {
        "if": ("", " you have time."),
    },
    "p1-u14": {
        "name": ("Fingerspell your ", "."),
    },
    "p1-u30": {
        "garage": ("Park in the ", "."),
    },
    "p1-u32": {
        "mirror": ("Look in the ", "."),
    },
    "p1-u37": {
        "chicken": ("Grill the ", " tonight."),
    },
    "p1-u40": {
        "early": ("Wake up ", " today."),
    },
    "p1-u50": {
        "watch": ("Check your ", "."),
    },
    "p1-u68": {
        "italy": ("We visit ", " next."),
        "mexico": ("We visit ", " next."),
    },
    "p1-u69": {
        "mouse": ("Click the ", "."),
    },
    "p1-u70": {
        "video": ("Watch this ", "."),
    },
    "p1-u71": {
        "always": ("I will ", " help."),
        "rightcorrect": ("That is ", "."),
    },
    "p1-u23": {
        "lost": ("I am ", "."),
        "imlost": ("", ", need directions."),
    },
    "p1-u38": {
        "imthirsty": ("I am ", "."),
    },
    "p1-u45": {
        "emergency": ("This is an ", "."),
        "police": ("Call the ", "."),
    },
    "p1-u77": {
        "whereareyoufrom": ("", "?"),
        "imfrom": ("", " America."),
        "whatareyoudoing": ("", " today?"),
    },
}

SEMANTIC_DISTRACTOR_CATEGORIES: dict[str, list[str]] = {
    "greetings": [
        "hello", "bye", "please", "thankyou", "sorry", "welcome", "name",
        "congratulations", "oops", "nice", "meet", "introduce", "sign",
        "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow",
        "yourewelcome", "goodmorning", "goodnight", "seeyoulater",
        "havegoodday", "excuseme", "nicetoseeyou", "thankyouverymuch",
    ],
    "politeness": [
        "please", "thankyou", "sorry", "welcome", "yourewelcome",
        "excuseme", "congratulations", "oops", "pleasehelpme",
    ],
    "responses": [
        "yes", "no", "sure", "wow", "really", "alright", "ok", "again", "wait",
        "nevermind", "maybe", "dontknow", "notyet", "signagain", "excuseme",
        "seeyoulater", "samehere", "havegoodday", "cool", "awesome", "funny",
    ],
    "pronouns": [
        "i", "me", "you", "we", "us", "our", "my", "your", "his", "mine", "he", "they",
        "she", "her", "him", "them", "their", "yours", "ours",
    ],
    "questions": [
        "what", "where", "when", "who", "why", "how", "which",
        "whatisyourname", "whatsthat", "whatdoesthatmean", "howmany", "whereareyou",
        "whatisyournamesign", "whereareyoufrom", "whatareyoudoing", "imfrom", "from", "doing",
    ],
    "people-words": [
        "person", "people", "myself", "yourself", "sign", "introduce", "nice", "meet",
    ],
    "mood-basics": [
        "good", "bad", "fine", "great", "happy", "sad", "tired", "angry", "scared",
        "excited", "worry", "imgood", "goodmorning", "goodnight",
        "imtired", "imhappy", "imsad", "imangry", "imscared", "imexcited", "imnervous",
        "nervous",
    ],
    "deaf-world": [
        "deaf", "hearing", "hardofhearing", "asl", "signlanguage", "namesign",
        "deafculture", "fluent", "learnasl", "whatisyournamesign", "imlearningasl",
        "interpreter", "caption", "hearingaid", "lipread", "gesture", "translate",
        "practice", "isignalittle",
    ],
    "accessibility": [
        "interpreter", "caption", "hearingaid", "lipread", "gesture", "translate",
    ],
    "alphabet": [
        "a", "b", "c", "d", "e", "f", "g", "h", "letteri", "j", "k", "l", "m", "n", "o", "p",
        "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    ],
    "fingerspelling": [
        "alphabet", "fingerspell", "letter", "language", "word", "name",
    ],
    "numbers": [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven",
    ],
    "money": ["money", "pay", "cost", "price", "1dollar", "5dollars"],
    "amounts-math": [
        "half", "quarter", "percent", "double", "triple", "hundred", "many", "few",
        "enough", "more", "less", "very", "almost", "really", "howmany", "much",
    ],
    "sentence-helpers": [
        "and", "but", "or", "so", "with", "without", "also", "because", "same",
        "different", "if",
    ],
    "family": [
        "mother", "father", "sister", "brother", "baby", "child", "family", "parents",
        "grandmother", "grandfather", "aunt", "uncle", "cousin", "niece", "nephew",
        "twins",
    ],
    "people": ["man", "woman", "boy", "girl", "adult", "teenager"],
    "movement": ["go", "come", "walk", "run", "stop", "turn", "move", "lost", "imlost"],
    "body-actions": [
        "eat", "drink", "sleep", "see", "hear", "feel", "breathe", "smell",
        "iwanteat", "iwantdrink",
    ],
    "communication": [
        "tell", "ask", "talk", "think", "know", "understand", "believe", "need", "help",
        "idontunderstand", "ineedhelp", "canyouhelpme", "pleasehelpme", "slow", "again", "wait",
        "repeat", "that", "canyourepeatthat", "pleasesignslower", "howyousignthat",
        "isignalittle", "call911", "call", "nineoneone", "little",
    ],
    "doing-helping": [
        "make", "get", "give", "take", "use", "find", "want", "help", "iwant", "try", "doing",
        "whatareyoudoing",
    ],
    "colors": [
        "red", "blue", "green", "yellow", "orangecolor", "purple", "pink", "brown", "black",
        "white", "gray", "gold", "silver", "bright",
    ],
    "descriptions": [
        "dark", "light", "bright", "big", "small", "tall", "fast", "slow", "hard",
    ],
    "home": [
        "home", "house", "kitchen", "bathroom", "bedroom", "livingroom", "basement",
        "backyard", "wherebathroom", "garage",
    ],
    "furniture": ["table", "chair", "bed", "couch", "door", "window", "lamp", "clock"],
    "hygiene": [
        "shower", "toilet", "sink", "soap", "toothbrush", "brush", "comb", "mirror",
    ],
    "chores": ["clean", "wash", "cook", "sweep", "vacuum", "washdishes"],
    "mealtime": ["breakfast", "lunch", "dinner", "hungry", "full", "delicious", "imhungry", "thirsty", "imthirsty"],
    "fruit": [
        "apple", "banana", "grapes", "strawberry", "cherry", "pineapple", "lemon",
        "orangefruit",
    ],
    "vegetables": ["tomato", "carrot", "corn", "onion", "potato", "lettuce"],
    "protein-dairy": [
        "meat", "fish", "egg", "cheese", "milk", "butter", "bacon", "chicken",
    ],
    "snacks-drinks": [
        "bread", "pizza", "cake", "chocolate", "water", "coffee", "tea", "juice",
        "thirsty", "imthirsty",
    ],
    "weekdays": [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "weekend",
    ],
    "time-of-day": [
        "morning", "afternoon", "night", "today", "yesterday", "tomorrow", "now", "noon",
        "later", "early",
    ],
    "time-units": [
        "day", "week", "month", "year", "hour", "minute", "weekend", "holiday",
    ],
    "head-face": ["head", "face", "eyes", "ear", "nose", "mouth", "teeth", "tongue"],
    "body": ["body", "arm", "hands", "finger", "shoulder", "neck", "back", "stomach"],
    "symptoms": [
        "sick", "hurt", "pain", "headache", "cough", "sneeze", "tired", "dizzy", "emergency",
    ],
    "health": ["health", "exercise", "doctor", "nurse", "hospital", "medicine", "police", "call911"],
    "personality": [
        "confident", "humble", "lazy", "stubborn", "curious", "serious", "remember",
        "forget", "cool", "awesome", "funny",
    ],
    "big-feelings": [
        "bored", "lonely", "jealous", "embarrass", "frustrate", "surprise",
    ],
    "relationships": ["love", "like", "hate", "friend", "hug", "kiss", "ilike"],
    "clothing": [
        "shirt", "pants", "dress", "shoes", "socks", "jacket", "hat", "clothes",
        "shorts", "skirt", "sweater", "boots", "gloves", "scarf", "belt", "suit",
    ],
    "accessories": [
        "glasses", "earring", "necklace", "bracelet", "ring", "backpack", "wallet",
        "watch",
    ],
    "transportation": [
        "car", "bus", "train", "airplane", "bike", "truck", "motorcycle", "boat",
    ],
    "directions": ["here", "there", "left", "right", "up", "down", "near", "far"],
    "places": ["shop", "park", "restaurant", "hotel", "library", "church"],
    "commute": ["drive", "ride", "arrive", "travel", "road", "street", "traffic", "commute"],
    "school": [
        "school", "class", "student", "teacher", "learn", "study", "read", "write",
        "math", "science", "history", "art", "book", "pen", "paper", "music",
    ],
    "work": [
        "work", "job", "boss", "lawyer", "engineer", "scientist", "meeting", "retire",
    ],
    "pets-farm": [
        "dog", "cat", "horse", "cow", "pig", "sheep", "rabbit", "duck",
    ],
    "wild-animals": [
        "lion", "tiger", "elephant", "bear", "wolf", "fox", "eagle", "monkey",
    ],
    "nature-seasons": [
        "tree", "flower", "mountain", "river", "ocean", "beach", "sun", "moon",
        "spring", "summer", "fall", "winter",
    ],
    "weather": ["rain", "snow", "wind", "cloud", "lightning", "thunder", "hot", "cold"],
    "sports": [
        "football", "basketball", "baseball", "soccer", "volleyball", "hockey", "tennis",
        "golf",
    ],
    "arts-hobbies": [
        "draw", "paint", "sing", "dance", "music", "guitar", "piano",
    ],
    "holidays": [
        "party", "birthday", "christmas", "halloween", "thanksgiving", "easter",
    ],
    "countries": [
        "america", "canada", "mexico", "france", "germany", "china", "japan", "italy",
    ],
    "tech": [
        "computer", "phone", "tablet", "laptop", "camera", "tv", "keyboard", "mouse",
    ],
    "online-media": [
        "internet", "email", "text", "download", "upload", "share", "send", "video",
    ],
    "big-ideas": [
        "can", "cannot", "maybe", "important", "rightcorrect", "wrong", "future", "always",
    ],
    "asl-phrases": sorted(PHRASE_IDS),
}


def _build_semantic_distractor_indexes() -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    word_to_categories: dict[str, set[str]] = {}
    category_to_words: dict[str, set[str]] = {}
    for category_id, words in SEMANTIC_DISTRACTOR_CATEGORIES.items():
        category_to_words[category_id] = set(words)
        for word in words:
            word_to_categories.setdefault(word, set()).add(category_id)
    return word_to_categories, category_to_words


WORD_TO_SEMANTIC_CATEGORIES, SEMANTIC_CATEGORY_WORDS = _build_semantic_distractor_indexes()


def semantic_distractor_peer_ids(word_id: str) -> set[str]:
    """All word ids sharing at least one semantic category with `word_id`."""
    peers: set[str] = set()
    for category_id in WORD_TO_SEMANTIC_CATEGORIES.get(word_id, set()):
        peers.update(SEMANTIC_CATEGORY_WORDS.get(category_id, set()))
    peers.discard(word_id)
    return peers


# English glosses that share one ASL production (alias → canonical playback / teach id).
SIGN_ALIAS_TO_CANONICAL: dict[str, str] = {
    "me": "i",
    "us": "we",
    "him": "he",
    "her": "she",
    "them": "they",
    "mine": "my",
    "yours": "your",
    "ours": "our",
}

SIGN_CANONICAL_PRONOUNS: frozenset[str] = frozenset(
    {
        "i",
        "you",
        "we",
        "he",
        "she",
        "they",
        "my",
        "your",
        "our",
        "his",
        "their",
    }
)

# Stone 3 English-grammar fill slots (alias answer, canonical sign video via app lookup).
ENGLISH_ALIAS_FILL_SLOTS: list[dict[str, object]] = [
    {
        "answerWordId": "me",
        "sentenceBefore": "Can you help ",
        "sentenceAfter": "?",
        "distractorWordIds": ["you", "him"],
    },
    {
        "answerWordId": "us",
        "sentenceBefore": "Come with ",
        "sentenceAfter": ".",
        "distractorWordIds": ["them", "you"],
    },
    {
        "answerWordId": "him",
        "sentenceBefore": "I told ",
        "sentenceAfter": " the news.",
        "distractorWordIds": ["she", "they"],
    },
    {
        "answerWordId": "her",
        "sentenceBefore": "I saw ",
        "sentenceAfter": " yesterday.",
        "distractorWordIds": ["him", "they"],
    },
    {
        "answerWordId": "them",
        "sentenceBefore": "Give it to ",
        "sentenceAfter": ".",
        "distractorWordIds": ["us", "him"],
    },
    {
        "answerWordId": "mine",
        "sentenceBefore": "That book is ",
        "sentenceAfter": ".",
        "distractorWordIds": ["your", "his"],
    },
    {
        "answerWordId": "yours",
        "sentenceBefore": "Is this ",
        "sentenceAfter": "?",
        "distractorWordIds": ["mine", "ours"],
    },
    {
        "answerWordId": "ours",
        "sentenceBefore": "The house is ",
        "sentenceAfter": ".",
        "distractorWordIds": ["their", "yours"],
    },
]


def canonical_sign_id(word_id: str) -> str:
    return SIGN_ALIAS_TO_CANONICAL.get(word_id, word_id)


def same_sign(a: str, b: str) -> bool:
    return canonical_sign_id(a) == canonical_sign_id(b)


def is_sign_alias(word_id: str) -> bool:
    return word_id in SIGN_ALIAS_TO_CANONICAL


def filter_distinct_sign_words(words: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for word in words:
        canonical = canonical_sign_id(word)
        if canonical in seen:
            continue
        seen.add(canonical)
        result.append(word)
    return result


MIN_SIGNS_PER_STONE = 10
STONE1_NEW_SIGN_TARGET = 8
STONE_COUNT = 3


def _allocate_singles_to_stones(singles: list[str]) -> list[list[str]]:
    """Give stone 1 a focused batch; spread the rest across stones 2–3."""
    batches: list[list[str]] = [[] for _ in range(STONE_COUNT)]
    total = len(singles)
    if total == 0:
        return batches
    if total <= STONE1_NEW_SIGN_TARGET:
        batches[0] = singles
        return batches

    idx = STONE1_NEW_SIGN_TARGET
    batches[0] = singles[:idx]
    for stone_idx in range(1, STONE_COUNT):
        remaining = total - idx
        stones_left = STONE_COUNT - stone_idx
        if remaining <= 0:
            break
        if stones_left == 1:
            take = remaining
        elif remaining >= MIN_SIGNS_PER_STONE * stones_left:
            take = MIN_SIGNS_PER_STONE
        elif remaining >= MIN_SIGNS_PER_STONE:
            take = MIN_SIGNS_PER_STONE
        elif stones_left == 2:
            take = remaining
        else:
            take = (remaining + stones_left - 1) // stones_left
        batches[stone_idx] = singles[idx:idx + take]
        idx += take
    return batches


def _place_phrases_on_stones(batches: list[list[str]], phrases: list[str]) -> None:
    """Spread phrase ids across stones 2–3 (at most two phrases per stone)."""
    if not phrases:
        return
    max_phrases_per_stone = 2
    phrase_stones = list(range(1, min(STONE_COUNT, len(batches))))
    if not phrase_stones:
        phrase_stones = [0]
    stone_phrase_counts = [0] * len(batches)
    for phrase in phrases:
        eligible = [
            index
            for index in phrase_stones
            if stone_phrase_counts[index] < max_phrases_per_stone
        ]
        if not eligible:
            eligible = phrase_stones
        target = min(
            eligible,
            key=lambda index: (stone_phrase_counts[index], len(batches[index])),
        )
        batches[target].append(phrase)
        stone_phrase_counts[target] += 1


def _allocate_words_evenly(words: list[str]) -> list[list[str]]:
    """Spread vocabulary across four stones when the unit is too small to front-load nine."""
    batches: list[list[str]] = [[] for _ in range(STONE_COUNT)]
    idx = 0
    total = len(words)
    for stone_idx in range(STONE_COUNT):
        remaining = total - idx
        stones_left = STONE_COUNT - stone_idx
        if remaining <= 0:
            break
        take = (remaining + stones_left - 1) // stones_left
        batches[stone_idx] = words[idx:idx + take]
        idx += take
    return batches


def _allocate_words_front_heavy(words: list[str]) -> list[list[str]]:
    """Pack vocabulary in journey order — nine new signs per stone when possible."""
    batches: list[list[str]] = [[] for _ in range(STONE_COUNT)]
    rest = list(words)
    for stone_idx in range(STONE_COUNT):
        if not rest:
            break
        stones_left = STONE_COUNT - stone_idx
        remaining = len(rest)
        if stones_left == 1:
            take = remaining
        elif remaining >= MIN_SIGNS_PER_STONE * stones_left:
            take = MIN_SIGNS_PER_STONE
        elif remaining >= MIN_SIGNS_PER_STONE:
            take = MIN_SIGNS_PER_STONE
        elif stones_left == 2:
            take = remaining
        else:
            take = (remaining + stones_left - 1) // stones_left
        batches[stone_idx] = rest[:take]
        rest = rest[take:]
    return batches


def _allocate_small_unit_words(words: list[str]) -> list[list[str]]:
    """Pick a fair per-stone split for units that cannot teach nine on every stone."""
    tail_floor = 2
    min_rest = tail_floor * (STONE_COUNT - 1)
    if len(words) - MIN_SIGNS_PER_STONE < min_rest:
        return _allocate_words_evenly(words)
    return _allocate_words_front_heavy(words)


def min_unique_answers_for_unit(unit_word_count: int) -> int:
    """Minimum distinct graded answers per stone (tiny units use fair share)."""
    if unit_word_count >= MIN_SIGNS_PER_STONE * STONE_COUNT:
        return MIN_SIGNS_PER_STONE
    if unit_word_count <= 0:
        return 0
    return max(1, (unit_word_count + STONE_COUNT - 1) // STONE_COUNT)


def _rebalance_stone1_batch(
    subsets: list[list[str]],
    words: list[str],
    minimum: int = MIN_SIGNS_PER_STONE,
) -> list[list[str]]:
    """Pull words forward from later stones until stone 1 meets the minimum."""
    target = min(minimum, len(words))
    if not subsets or len(subsets[0]) >= target:
        return subsets
    batches = [list(batch) for batch in subsets]
    while len(batches[0]) < target:
        moved = False
        for stone_idx in range(1, len(batches)):
            donor = batches[stone_idx]
            non_phrase = [word for word in donor if word not in PHRASE_IDS]
            if not non_phrase:
                continue
            for word in non_phrase:
                if len(batches[0]) >= target:
                    break
                donor.remove(word)
                batches[0].append(word)
                moved = True
            if len(batches[0]) >= target:
                break
        if not moved:
            break
    return batches


def stone1_review_candidates(
    unit_sort_order: int,
    prior_pool: list[str],
    stone1_subset: list[str],
    max_count: int = 2,
) -> list[str]:
    """Path-review words allowed as Stone 1 answers after path start (not in subset)."""
    if unit_sort_order <= 1:
        return []
    subset_set = set(stone1_subset)
    candidates = [
        word
        for word in prior_pool
        if word not in subset_set and word not in PHRASE_IDS
    ]
    return candidates[:max_count]


def build_unit_stone_subsets(words: list[str]) -> list[list[str]]:
    """Auto-split unit vocabulary into three stone batches (min ten signs when possible)."""
    singles = [w for w in words if w not in PHRASE_IDS]
    phrases = [w for w in words if w in PHRASE_IDS]
    small_unit = len(words) < MIN_SIGNS_PER_STONE * STONE_COUNT

    if phrases:
        if small_unit:
            batches = _allocate_small_unit_words(singles)
        else:
            batches = _allocate_singles_to_stones(singles)
        while len(batches) < STONE_COUNT:
            batches.append([])
        _place_phrases_on_stones(batches[:STONE_COUNT], phrases)
        return batches[:STONE_COUNT]

    if small_unit:
        return _allocate_small_unit_words(words)[:STONE_COUNT]

    batches = _allocate_singles_to_stones(singles)
    while len(batches) < STONE_COUNT:
        batches.append([])
    return batches[:STONE_COUNT]


def _ease_stone1_subset(
    batches: list[list[str]],
    target: int = STONE1_NEW_SIGN_TARGET,
) -> list[list[str]]:
    """Move excess stone-1 atomic signs forward to stone 2 for a lighter first stone."""
    if len(batches) < 2:
        return batches
    result = [list(batch) for batch in batches]
    s1_atomic = [word for word in result[0] if word not in PHRASE_IDS]
    while len(s1_atomic) > target:
        word = s1_atomic.pop()
        result[0].remove(word)
        result[1].insert(0, word)
    return result


def normalize_unit_stone_subsets(
    words: list[str],
    manual: list[list[str]] | None,
) -> list[list[str]]:
    minimum = min(STONE1_NEW_SIGN_TARGET, min_unique_answers_for_unit(len(words)))
    full_size_unit = len(words) >= MIN_SIGNS_PER_STONE * STONE_COUNT
    if manual and len(manual) == STONE_COUNT:
        flat = [word for batch in manual for word in batch]
        if set(flat) == set(words) and len(flat) == len(words):
            batches = [list(batch) for batch in manual]
            if full_size_unit and len(batches[0]) < minimum:
                batches = _rebalance_stone1_batch(batches, words, minimum)
            batches = _ease_stone1_subset(batches)
            return batches
    batches = build_unit_stone_subsets(words)
    if full_size_unit:
        batches = _rebalance_stone1_batch(batches, words, minimum)
    batches = _ease_stone1_subset(batches)
    return batches


def _build_all_unit_stone_subsets() -> dict[str, list[list[str]]]:
    result: dict[str, list[list[str]]] = {}
    for unit_id, _title, _desc, _badge, words in UNIT_SPECS:
        manual = MANUAL_UNIT_STONE_WORD_SUBSETS.get(unit_id)
        result[unit_id] = normalize_unit_stone_subsets(words, manual)
    return result


UNIT_STONE_WORD_SUBSETS: dict[str, list[list[str]]] = _build_all_unit_stone_subsets()


def cumulative_stone_words(unit_id: str, stone: int) -> list[str] | None:
    """Return cumulative word ids taught through `stone` (1-based), or None if no subsets."""
    subsets = UNIT_STONE_WORD_SUBSETS.get(unit_id)
    if not subsets:
        return None
    cumulative: list[str] = []
    for index in range(min(stone, len(subsets))):
        for word in subsets[index]:
            if word not in cumulative:
                cumulative.append(word)
    return cumulative


def stone_phrase_ids(unit_id: str, stone: int) -> list[str]:
    """Phrase ids introduced on this stone (for signSequence blocks)."""
    subsets = UNIT_STONE_WORD_SUBSETS.get(unit_id)
    if not subsets or stone < 1 or stone > len(subsets):
        return []
    return [word for word in subsets[stone - 1] if word in PHRASE_IDS]
