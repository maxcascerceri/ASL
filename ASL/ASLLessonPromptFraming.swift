import Foundation

enum ASLLessonPromptFraming {
    private static let watchChoose = [
        "What sign is this?",
        "Choose the correct sign.",
    ]

    private static let watchChoosePhrase = [
        "What phrase is this?",
        "Choose the correct phrase.",
    ]

    private static let fillSlot = [
        "Fill the blank in the sentence.",
        "What sign belongs here?",
        "Choose the missing sign.",
    ]

    private static let phraseSlot = [
        "Which sign is missing?",
    ]

    private static let signSequence = [
        "Complete this phrase.",
    ]

    private static let translationChoose = [
        "Choose the correct translation.",
        "What does this sign mean?",
        "Pick the meaning.",
    ]

    private static let matchPairs = [
        "Tap the matching pair.",
        "Match signs with translations.",
        "Pair each sign with its word.",
        "Connect signs to meanings.",
        "Match the signs and words.",
    ]

    private static let wordPickVideoTemplates = [
        "Pick out {word}.",
        "Find {word}.",
        "Choose {word}.",
        "Which video shows {word}?",
        "Match this sign: {word}.",
    ]

    private static let wordPickVideoPhrase = [
        "Match this phrase.",
    ]

    private static let newSignIntroduction = [
        "New sign!",
        "First time seeing this",
    ]

    private static let phraseIntroduction = [
        "Learn a new phrase!",
        "Watch this phrase!",
        "Here's a new phrase!",
        "See the whole sign!",
    ]

    private static let teachPhrase = [
        "Learn a new phrase!",
        "Watch this phrase!",
        "Here's a new phrase!",
        "See the whole sign!",
    ]

    private static let yourTurnWatch = [
        "Watch this sign, then record on your own.",
        "Study the example, then try signing it yourself.",
        "Watch closely — you'll record this sign next.",
    ]

    struct YourTurnReviewPrompt: Equatable {
        let headline: String
        let subline: String
    }

    private static let yourTurnReview: [YourTurnReviewPrompt] = [
        .init(
            headline: "Does your sign match?",
            subline: "Re-record if you want another try, or tap Done."
        ),
        .init(
            headline: "Compare with the example.",
            subline: "Re-record if needed, or tap Done when your sign matches."
        ),
        .init(
            headline: "Check your recording.",
            subline: "Re-record for another try, or tap Done when you're ready."
        ),
    ]

    /// Rotating headline when a word appears for the first time in a lesson.
    static func introductionPrompt(
        for wordId: String,
        lessonId: String,
        stepIndex: Int
    ) -> String {
        if ASLPhraseIds.contains(wordId) {
            let seed = adler32("\(lessonId):intro:\(stepIndex):\(wordId)")
            return phraseIntroduction[Int(seed % UInt32(phraseIntroduction.count))]
        }
        let seed = adler32("\(lessonId):intro:\(stepIndex):\(wordId)")
        return newSignIntroduction[Int(seed % UInt32(newSignIntroduction.count))]
    }

    /// Short label above the word on teach / new-sign beats.
    static func teachTitle(
        for wordId: String,
        lessonId: String,
        stepIndex: Int,
        isPracticeReplay: Bool = false
    ) -> String {
        if isPracticeReplay { return "Quick replay" }
        if ASLPhraseIds.contains(wordId) {
            let seed = adler32("\(lessonId):teach:\(stepIndex):\(wordId)")
            return teachPhrase[Int(seed % UInt32(teachPhrase.count))]
        }
        let seed = adler32("\(lessonId):teach:\(stepIndex):\(wordId)")
        return newSignIntroduction[Int(seed % UInt32(newSignIntroduction.count))]
    }

    static func yourTurnWatchSubtitle(
        lessonId: String,
        wordId: String,
        authoredPrompt: String
    ) -> String {
        if !authoredPrompt.isEmpty { return authoredPrompt }
        let seed = adler32("\(lessonId):yourturn-watch:\(wordId)")
        return yourTurnWatch[Int(seed % UInt32(yourTurnWatch.count))]
    }

    static func yourTurnReviewPrompt(lessonId: String, wordId: String) -> YourTurnReviewPrompt {
        let seed = adler32("\(lessonId):yourturn-review:\(wordId)")
        return yourTurnReview[Int(seed % UInt32(yourTurnReview.count))]
    }

    static func prompt(
        for kind: ModuleStepKind,
        lessonId: String,
        stepIndex: Int,
        wordId: String? = nil,
        wordLabel: String? = nil
    ) -> String {
        let frames: [String]
        if kind == .watchChoose, let wordId, ASLPhraseIds.contains(wordId) {
            frames = watchChoosePhrase
        } else if kind == .wordPickVideo, let wordId, ASLPhraseIds.contains(wordId) {
            frames = wordPickVideoPhrase
        } else {
            frames = Self.options(for: kind)
        }
        guard !frames.isEmpty else { return "" }

        let seed = adler32("\(lessonId):\(stepIndex):\(kind.rawValue)")
        let template = frames[Int(seed % UInt32(frames.count))]

        if kind == .wordPickVideo,
           let wordId, !ASLPhraseIds.contains(wordId),
           let wordLabel, !wordLabel.isEmpty {
            return template.replacingOccurrences(of: "{word}", with: wordLabel)
        }
        return template
    }

    private static func options(for kind: ModuleStepKind) -> [String] {
        switch kind {
        case .watchChoose: return watchChoose
        case .fillSlot: return fillSlot
        case .phraseSlot: return phraseSlot
        case .signSequence: return signSequence
        case .translationChoose: return translationChoose
        case .matchPairs: return matchPairs
        case .wordPickVideo: return wordPickVideoTemplates
        default: return []
        }
    }

    /// Stable seed aligned with `zlib.adler32` in the curriculum generator.
    private static func adler32(_ string: String) -> UInt32 {
        var s1: UInt32 = 1
        var s2: UInt32 = 0
        let mod: UInt32 = 65521
        for byte in string.utf8 {
            s1 = (s1 + UInt32(byte)) % mod
            s2 = (s2 + s1) % mod
        }
        return (s2 << 16) | s1
    }
}
