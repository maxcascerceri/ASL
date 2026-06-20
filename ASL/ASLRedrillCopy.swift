import Foundation

/// Mastery-oriented copy for the module polish round and related feedback.
enum ASLRedrillCopy {
    private static let firstPassWrongHeadlines = [
        "Almost",
        "So close",
        "Good effort",
        "Keep going",
        "One more look",
    ]

    static let introHeadline = "Let's correct\nsome mistakes"
    static let introSubtitle = "A few mistakes are completely normal!"
    static let introCTA = "Continue"
    static let reviewLabel = "REVIEW"
    static let polishRetryHint = "Pick again"
    static let polishPromptHint = "Choose an answer"

    static func firstPassWrongHeadline(index: Int) -> String {
        guard !firstPassWrongHeadlines.isEmpty else { return "Almost" }
        return firstPassWrongHeadlines[index % firstPassWrongHeadlines.count]
    }
}
