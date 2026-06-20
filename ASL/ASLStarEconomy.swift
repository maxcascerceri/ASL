//
//  ASLStarEconomy.swift
//  ASL
//
//  Central star payouts for lessons, checkpoints, milestones, streaks, and
//  dictionary study. Tune these values without touching gameplay views.
//

import Foundation

struct StoneCompletionAward: Equatable {
    let stone: Int
    let perfectBonus: Int
    let unitGateway: Int
    let unitMilestone: Int

    var total: Int { stone + perfectBonus + unitGateway + unitMilestone }

    static let zero = StoneCompletionAward(
        stone: 0,
        perfectBonus: 0,
        unitGateway: 0,
        unitMilestone: 0
    )
}

enum ASLStarEconomy {
    // MARK: - Lesson stones (path)

    /// Module stones: 4 / 5 / 6 stars for stones 1–3.
    static func moduleStoneReward(sortOrder: Int) -> Int {
        let rewards = [4, 5, 6]
        let index = max(0, min(sortOrder, rewards.count) - 1)
        return rewards[index]
    }

    /// Extra stars when the learner clears a stone on the first pass with no misses.
    static let modulePerfectPassBonus = 2

    /// Flat star payout for completing the onboarding intro lesson.
    static let onboardingLessonStarReward = 25

    static var onboardingLessonStarAward: StoneCompletionAward {
        StoneCompletionAward(
            stone: onboardingLessonStarReward,
            perfectBonus: 0,
            unitGateway: 0,
            unitMilestone: 0
        )
    }

    // MARK: - Checkpoint unit gateway

    /// Extra stars when clearing the crown / checkpoint that finishes a unit.
    static let unitGatewayBonus = 15

    /// Bonus every Nth **unit** by `sortOrder` (e.g. 5 → star units 5, 10, …).
    static func everyNthUnitMilestoneBonus(sortOrder: Int, n: Int = 5) -> Int {
        guard n > 0, sortOrder > 0, sortOrder.isMultiple(of: n) else { return 0 }
        return 30
    }

    // MARK: - In-lesson streak (modules, select-and-check flows)

    /// Streak counts that trigger the in-module celebration pop-up.
    static let inLessonStreakCelebrationThresholds: Set<Int> = [5, 10, 20, 40]

    // MARK: - Dictionary “learned”

    /// First time the learner opens a sign from the dictionary.
    static let wordStudied = 1

    // MARK: - Practice daily tasks (Practice tab)

    static let dailyPracticeQuiz = 5
    static let dailyPracticeFlashcards = 5
    static let dailyPracticeSpellYourName = 5
    /// Navigation-only goal; unit stars are awarded on the path.
    static let dailyPracticeFinishUnit = 0
    static let dailyPracticeDictionaryCategory = 4
    static let dailyPracticeDictionaryFavorites = 4
    static let dailyPracticeQuizCorrect = 5
    static let dailyPracticeWeakSigns = 5
}
