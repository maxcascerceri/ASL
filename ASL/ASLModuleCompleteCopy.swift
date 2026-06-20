import Foundation

/// Copy for the full-screen stone completion celebration.
enum ASLModuleCompleteCopy {
    private static let headlines = [
        "You crushed it!",
        "Nice work!",
        "Stone complete!",
        "Locked in!",
        "On a roll!",
        "Great job!",
    ]

    static let subtitle = "You earned this. Keep going!"
    static let continueCTA = "Continue"

    static func nextStoneCTA(nextStone: ASLLesson, unit: ASLUnit) -> String {
        let title = ASLStoneDisplayTitles.title(for: nextStone, unit: unit)
        return "Start Stone \(nextStone.sortOrder) - \(title)"
    }

    static func headline(index: Int) -> String {
        guard !headlines.isEmpty else { return "You crushed it!" }
        return headlines[index % headlines.count]
    }

    static func randomHeadlineIndex() -> Int {
        Int.random(in: 0..<headlines.count)
    }
}
