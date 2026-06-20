import Foundation

/// Category-aware distractor peers for watchChoose / translationChoose top-up.
/// Mirrors `SEMANTIC_DISTRACTOR_CATEGORIES` in scripts/curriculum_v5_data.py.
enum ASLSemanticDistractors {
    private static let categories: [String: [String]] = [
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
        "asl-phrases": [
            "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow",
            "yourewelcome", "dontknow", "notyet", "signagain", "excuseme", "seeyoulater",
            "samehere", "havegoodday", "whatisyourname", "whatsthat", "whatdoesthatmean",
            "imgood", "goodmorning", "goodnight", "idontunderstand", "ineedhelp",
            "canyouhelpme", "pleasehelpme", "wherebathroom",
            "nicetoseeyou", "letmesee", "howyousignthat", "onemoretime", "talktoyoulater",
            "blowmind", "allofsudden", "wrapup", "letgo",
            "imtired", "imhappy", "imsad", "imangry", "imscared",
            "iwant", "ilike", "imhungry", "iwanteat", "iwantdrink",
            "howmany", "whereareyou", "whatisyournamesign", "imlearningasl",
            "isignalittle", "canyourepeatthat", "pleasesignslower", "thankyouverymuch",
            "whereareyoufrom", "imfrom", "whatareyoudoing", "imexcited", "imnervous",
            "imthirsty", "call911", "imlost",
        ],
    ]

    private static let wordToCategories: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for (categoryID, words) in categories {
            for word in words {
                map[word, default: []].insert(categoryID)
            }
        }
        return map
    }()

    private static let categoryToWords: [String: Set<String>] = {
        categories.mapValues { Set($0) }
    }()

    static func candidates(for answerWordId: String, pool: [String]) -> [String] {
        let poolSet = Set(pool)
        var peers = Set<String>()
        for categoryID in wordToCategories[answerWordId] ?? [] {
            peers.formUnion(categoryToWords[categoryID] ?? [])
        }
        peers.remove(answerWordId)
        return peers.intersection(poolSet).sorted()
    }

    /// Semantic peers for single-word fill-slot distractors when the stone pool
    /// is too small (not restricted to the lesson vocabulary).
    static func singleWordPeers(for answerWordId: String) -> [String] {
        var peers = Set<String>()
        for categoryID in wordToCategories[answerWordId] ?? [] {
            peers.formUnion(categoryToWords[categoryID] ?? [])
        }
        peers.remove(answerWordId)
        return peers.filter { !ASLPhraseIds.contains($0) }.sorted()
    }
}
