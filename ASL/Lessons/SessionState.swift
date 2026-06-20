//
//  SessionState.swift
//  ASL
//
//  Generic per-stone session model. Each gameplay view instantiates one with
//  its concrete `Question` type and uses the shared advance / record APIs
//  to drive the dopamine loop.
//

import Combine
import Foundation

@MainActor
final class StoneSession<Question>: ObservableObject {
    @Published private(set) var questions: [Question]
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var missedWords: [String] = []
    @Published private(set) var isComplete: Bool = false

    /// Consecutive correct answers in the current session. Resets to 0 on any
    /// wrong answer (or reload). Used by `ModuleLessonView` to fire the streak
    /// celebration at 5-, 10-, 20-, and 40-in-a-row milestones.
    @Published private(set) var currentStreak: Int = 0

    /// Highest `currentStreak` value observed during this session.
    @Published private(set) var bestStreak: Int = 0

    private var missedSet: Set<String> = []

    init(questions: [Question], startIndex: Int = 0) {
        self.questions = questions
        guard !questions.isEmpty else { return }
        currentIndex = max(0, min(startIndex, questions.count - 1))
    }

    var current: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    /// 0..1 progress for the lesson shell's progress bar. Counts the
    /// *finished* questions so the bar reaches 1.0 the moment the user
    /// answers the final one correctly.
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    /// Total question count, used by views that want to render a counter.
    var total: Int { questions.count }

    func recordCorrect() {
        correctCount += 1
        currentStreak += 1
        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }
    }

    func recordWrong(wordId: String) {
        wrongCount += 1
        currentStreak = 0
        if !missedSet.contains(wordId) {
            missedSet.insert(wordId)
            missedWords.append(wordId)
        }
    }

    /// Advance to the next question or mark the session complete.
    func advance() {
        if currentIndex + 1 >= questions.count {
            isComplete = true
            currentIndex = questions.count
        } else {
            currentIndex += 1
        }
    }

    /// Advance to the next question, wrapping to the start for timed speed rounds.
    func advanceCycling() {
        guard !questions.isEmpty else { return }
        isComplete = false
        currentIndex = (currentIndex + 1) % questions.count
    }

    /// Replace the question queue (used by checkpoint re-drill loops).
    func reload(with newQuestions: [Question]) {
        questions = newQuestions
        currentIndex = 0
        correctCount = 0
        wrongCount = 0
        currentStreak = 0
        bestStreak = 0
        missedSet.removeAll()
        missedWords.removeAll()
        isComplete = false
    }

    /// Restart the current queue from the first question without rebuilding it.
    func resetToStart() {
        reload(with: questions)
    }

    /// Insert questions immediately after the current position without resetting
    /// progress. Used by Review Mode to splice in a refresher + retry so the
    /// session can't complete until the new items are cleared too.
    func insertNext(_ items: [Question]) {
        guard !items.isEmpty else { return }
        let insertAt = min(currentIndex + 1, questions.count)
        questions.insert(contentsOf: items, at: insertAt)
        isComplete = false
    }
}
