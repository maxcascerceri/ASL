import Foundation

struct ASLWord: Identifiable, Hashable {
    let id: String
    let text: String
    let normalizedText: String
    let videoCount: Int
    let categoryIds: [String]
    /// Firebase Storage path for grid poster JPEG, when set on the word doc.
    let posterStoragePath: String?
}

enum ASLWordDisplay {
    private static let overrides: [String: String] = [
        "1dollar": "1 Dollar",
        "5dollars": "5 Dollars",
        "allofsudden": "All Of A Sudden",
        "america": "America / USA",
        "asl": "ASL",
        "awesome": "Awesome",
        "blowmind": "Blow Mind",
        "call": "Call",
        "call911": "Call 911",
        "canyouhelpme": "Can You Help Me",
        "canyourepeatthat": "Can You Repeat That?",
        "cool": "Cool",
        "deafculture": "Deaf Culture",
        "doing": "Doing",
        "dontknow": "Don't Know",
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
        "icecream": "Ice Cream",
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
        "nineoneone": "911",
        "nicetomeetyou": "Nice To Meet You",
        "nicetoseeyou": "Nice To See You",
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
    ]

    /// Phrase-specific labels for shared sign ids (e.g. YOUR in "You're welcome").
    private static let phraseComponentOverrides: [String: [String: String]] = [
        "yourewelcome": ["your": "You're"],
    ]

    static func phraseComponentTitle(
        wordId: String,
        phraseId: String,
        catalogText: String? = nil
    ) -> String {
        let wordKey = wordId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let phraseKey = phraseId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let override = phraseComponentOverrides[phraseKey]?[wordKey] {
            return override
        }
        return title(for: catalogText ?? wordId)
    }

    static func title(for raw: String) -> String {
        let key = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let override = overrides[key] {
            return override
        }

        let spaced = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return spaced
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

enum ASLPhraseIds {
    static let ids: Set<String> = [
        "allofsudden", "blowmind", "call911", "canyouhelpme", "canyourepeatthat", "dontknow",
        "excuseme", "goodmorning", "goodnight", "havegoodday", "howareyou", "howmany",
        "howyousignthat", "idontunderstand", "ilike", "imfine", "imexcited", "imfrom",
        "imhappy", "imhungry", "imangry", "imgood", "imlearningasl", "imlost", "imnervous",
        "imsad", "imscared", "imthirsty", "imtired", "ineedhelp", "isignalittle", "iwant",
        "iwantdrink", "iwanteat", "letgo", "letmesee", "mynameis", "nicetomeetyou",
        "nicetoseeyou", "notyet", "onemoretime", "pleasehelpme", "pleasesignslower",
        "samehere", "seeyoulater", "signagain", "signslow", "talktoyoulater",
        "thankyouverymuch", "whatdoesthatmean", "whatareyoudoing", "whatisyourname",
        "whatisyournamesign", "whatsthat", "whereareyou", "whereareyoufrom", "wherebathroom",
        "wrapup", "yourewelcome",
    ]

    static func contains(_ wordId: String) -> Bool {
        ids.contains(wordId)
    }
}

struct ASLVideo: Identifiable, Hashable {
    let id: String
    let word: String
    let storagePath: String
    let sourcePath: String
    let sortOrder: Int
    let fileSizeBytes: Int64?
    var playbackURL: URL?
}

struct ASLPath: Identifiable, Hashable {
    let id: String
    let title: String
    let tagline: String
    let colorHex: String
    let sortOrder: Int
    let unitCount: Int
}

struct ASLUnit: Identifiable, Hashable {
    let id: String
    let pathId: String
    let title: String
    let description: String
    let badge: String
    let sortOrder: Int
    let mandatoryGateway: Bool
    let isReview: Bool
    /// Recap checkpoint for a phase (`Phase {name} Review`), not a lesson unit.
    let isPhaseReview: Bool
    /// Legacy Firestore field; milestone challenges removed from the path.
    let isMilestone: Bool
    let lessonCount: Int
    let phaseKey: String?
    let phaseTitle: String?
}

enum ASLLessonType: String, Hashable {
    case module
    case watchPick2
    case watchPick4
    case fillGap
    case speed
    case checkpoint
    case unknown

    init(raw: String) {
        self = ASLLessonType(rawValue: raw) ?? .unknown
    }
}

struct FillGapQuestion: Hashable {
    let sentenceBefore: String
    let sentenceAfter: String
    let answerWordId: String
    let distractorWordIds: [String]
}

enum ModuleStepKind: String, Hashable {
    case teach
    case watchPick2
    case watchPick4
    case wordPickVideo
    case sameDifferent
    case meaningPick
    case watchThenPick
    case watchChoose
    case translationChoose
    case memoryCountdown
    case fillSlot
    case phraseSlot
    case matchPairs
    case signSequence
    case speedBurst
    case fillGap
    case selfSign
    case yourTurn
    case aslTip
    case unknown

    init(raw: String) {
        self = ModuleStepKind(rawValue: raw) ?? .unknown
    }
}

struct ModuleStep: Hashable {
    let kind: ModuleStepKind
    let wordId: String?
    let answerWordId: String?
    let comparisonWordId: String?
    let sentenceBefore: String
    let sentenceAfter: String
    let distractorWordIds: [String]
    let pairWordIds: [String]
    let sequenceWordIds: [String]
    let slotIndex: Int?
    let questionWordIds: [String]
    let choiceCount: Int?
    let timePerQuestionMs: Int?
    let title: String
    let prompt: String
    let correctChoice: String
    let tipId: String?
}

struct CheckpointDistribution: Hashable {
    let watchPick2: Double
    let watchPick4: Double
    let fillGap: Double

    static let defaultSplit = CheckpointDistribution(watchPick2: 0.3, watchPick4: 0.4, fillGap: 0.3)
}

struct CheckpointConfig: Hashable {
    let passRatio: Double
    let lengthMultiplier: Int
    let distribution: CheckpointDistribution
    let redrillType: ASLLessonType
    let redrillPassRatio: Double
    let selfSignFinale: Bool

    static let defaults = CheckpointConfig(
        passRatio: 0.75,
        lengthMultiplier: 2,
        distribution: .defaultSplit,
        redrillType: .watchPick4,
        redrillPassRatio: 1.0,
        selfSignFinale: true
    )
}

struct ASLLesson: Identifiable, Hashable {
    let id: String
    let pathId: String
    let unitId: String
    let title: String
    /// Optional curriculum-authored label for home path stones (falls back to templated titles).
    let displayTitle: String?
    let type: ASLLessonType
    let sortOrder: Int
    let wordIds: [String]
    let questions: [FillGapQuestion]
    let steps: [ModuleStep]
    let timePerQuestionMs: Int?
    let config: CheckpointConfig?
}
