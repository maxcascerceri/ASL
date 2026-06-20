import Foundation

/// Copy for in-lesson streak milestone celebrations (5 / 10 / 20 / 40 in a row).
enum ASLStreakCelebrationCopy {
    private static let headlinesByThreshold: [Int: [String]] = [
        5: ["Locked in!", "Clean run!", "Five straight!"],
        10: ["On a roll!", "Ten straight!", "Smooth!"],
        20: ["Unstoppable!", "Twenty deep!", "Still going!"],
        40: ["Flawless focus!", "Forty straight!", "Precision!"],
    ]

    static func headline(streak: Int) -> String {
        let pool = headlinesByThreshold[streak] ?? ["Nice streak!"]
        guard !pool.isEmpty else { return "Nice streak!" }
        return pool[streak % pool.count]
    }
}

/// Rotating headlines for the in-lesson correct-answer tray pop-up.
enum ASLCorrectFeedbackCopy {
    private static let headlines = [
        "Amazing!",
        "Nice!",
        "Great job!",
        "You got it!",
        "Perfect!",
        "Strong!",
        "Yes!",
        "Nailed it!",
        "Well done!",
        "Spot on!",
    ]

    static func headline(index: Int) -> String {
        guard !headlines.isEmpty else { return "Nice!" }
        return headlines[index % headlines.count]
    }
}
