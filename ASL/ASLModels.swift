import Foundation

struct ASLWord: Identifiable, Hashable {
    let id: String
    let text: String
    let normalizedText: String
    let videoCount: Int
    let categoryIds: [String]
}

enum ASLWordDisplay {
    private static let overrides: [String: String] = [
        "1dollar": "1 Dollar",
        "5dollars": "5 Dollars",
        "allofsudden": "All Of A Sudden",
        "blowmind": "Blow Mind",
        "canyouhelpme": "Can You Help Me",
        "dontknow": "Don't Know",
        "excuseme": "Excuse Me",
        "giveup": "Give Up",
        "goodmorning": "Good Morning",
        "goodnight": "Good Night",
        "hardofhearing": "Hard Of Hearing",
        "havegoodday": "Have A Good Day",
        "hearingaid": "Hearing Aid",
        "howareyou": "How Are You",
        "howyousignthat": "How Do You Sign That",
        "iamdeaf": "I Am Deaf",
        "iamhearing": "I Am Hearing",
        "icecream": "Ice Cream",
        "idontunderstand": "I Don't Understand",
        "imfine": "I'm Fine",
        "imgood": "I'm Good",
        "imlearningasl": "I'm Learning ASL",
        "imsorry": "I'm Sorry",
        "ineedhelp": "I Need Help",
        "letgo": "Let Go",
        "letmesee": "Let Me See",
        "livingroom": "Living Room",
        "mynameis": "My Name Is",
        "nevermind": "Never Mind",
        "nicetomeetyou": "Nice To Meet You",
        "nicetoseeyou": "Nice To See You",
        "notyet": "Not Yet",
        "onemoretime": "One More Time",
        "samehere": "Same Here",
        "seeyoulater": "See You Later",
        "signagain": "Sign Again",
        "signlanguage": "Sign Language",
        "signslow": "Sign Slow",
        "talktoyoulater": "Talk To You Later",
        "thankyou": "Thank You",
        "washdishes": "Wash Dishes",
        "whatdoesthatmean": "What Does That Mean",
        "whatisyourname": "What's Your Name",
        "whatsthat": "What's That",
        "wherebathroom": "Where Is The Bathroom",
        "wrapup": "Wrap Up",
        "yourewelcome": "You're Welcome"
    ]

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
    case matchPairs
    case fillGap
    case selfSign
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
    let choiceCount: Int?
    let timePerQuestionMs: Int?
    let title: String
    let prompt: String
    let correctChoice: String
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
    let type: ASLLessonType
    let sortOrder: Int
    let wordIds: [String]
    let questions: [FillGapQuestion]
    let steps: [ModuleStep]
    let timePerQuestionMs: Int?
    let config: CheckpointConfig?
}
