//
//  PracticeDailyTasks.swift
//  ASL
//

import Foundation

enum PracticeDailyTaskKind: String, Codable, CaseIterable {
    case quizSession
    case flashcardsSession
    case spellYourNameSession
    case finishUnit
    case dictionaryCategory
    case dictionaryFavorites
    case quizCorrectCount
    case weakSignsQuiz
}

struct PracticeDailyTaskSpec: Codable, Equatable {
    let slot: Int
    let kind: PracticeDailyTaskKind
    let params: [String: String]

    var instanceKey: String {
        let paramKey = params.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return "\(slot):\(kind.rawValue):\(paramKey)"
    }
}

struct PracticeDailyTask: Identifiable {
    let spec: PracticeDailyTaskSpec
    let title: String
    let target: Int
    let starReward: Int
    let progress: Int
    let isClaimed: Bool
    let deepLink: PracticeDailyDeepLink
    let systemImage: String

    var id: String { spec.instanceKey }
    var instanceKey: String { spec.instanceKey }

    var isComplete: Bool { progress >= target }
    var canClaim: Bool { isComplete && !isClaimed }

    var progressLabel: String {
        "\(min(progress, target))/\(target)"
    }

    var progressFraction: Double {
        guard target > 0 else { return 0 }
        return Double(min(progress, target)) / Double(target)
    }
}

struct PracticeDailyTasksSnapshot: Codable {
    var periodKey: String
    var periodStartedAt: TimeInterval
    var resetsAt: TimeInterval
    var selectedTasks: [PracticeDailyTaskSpec]
    var progressByKey: [String: Int]
    var claimedTaskKeys: [String]

    static func fresh(periodKey: String, startedAt: TimeInterval, resetsAt: TimeInterval, tasks: [PracticeDailyTaskSpec]) -> PracticeDailyTasksSnapshot {
        PracticeDailyTasksSnapshot(
            periodKey: periodKey,
            periodStartedAt: startedAt,
            resetsAt: resetsAt,
            selectedTasks: tasks,
            progressByKey: [:],
            claimedTaskKeys: []
        )
    }
}

enum PracticeDailyTaskTemplates {
    static func starReward(for spec: PracticeDailyTaskSpec) -> Int {
        switch spec.kind {
        case .quizSession:
            return ASLStarEconomy.dailyPracticeQuiz
        case .flashcardsSession:
            return ASLStarEconomy.dailyPracticeFlashcards
        case .spellYourNameSession:
            return ASLStarEconomy.dailyPracticeSpellYourName
        case .finishUnit:
            return ASLStarEconomy.dailyPracticeFinishUnit
        case .dictionaryCategory:
            return ASLStarEconomy.dailyPracticeDictionaryCategory
        case .dictionaryFavorites:
            return ASLStarEconomy.dailyPracticeDictionaryFavorites
        case .quizCorrectCount:
            return ASLStarEconomy.dailyPracticeQuizCorrect
        case .weakSignsQuiz:
            return ASLStarEconomy.dailyPracticeWeakSigns
        }
    }

    static func tasks(
        from snapshot: PracticeDailyTasksSnapshot,
        store: ASLDataStore
    ) -> [PracticeDailyTask] {
        snapshot.selectedTasks.map { spec in
            let progress = snapshot.progressByKey[spec.instanceKey] ?? 0
            let metadata = metadata(for: spec, store: store)
            return PracticeDailyTask(
                spec: spec,
                title: metadata.title,
                target: metadata.target,
                starReward: metadata.reward,
                progress: progress,
                isClaimed: snapshot.claimedTaskKeys.contains(spec.instanceKey),
                deepLink: metadata.deepLink,
                systemImage: metadata.systemImage
            )
        }
    }

    private static func metadata(
        for spec: PracticeDailyTaskSpec,
        store: ASLDataStore
    ) -> (title: String, target: Int, reward: Int, deepLink: PracticeDailyDeepLink, systemImage: String) {
        switch spec.kind {
        case .quizSession:
            return (
                "Complete Daily Quiz",
                1,
                ASLStarEconomy.dailyPracticeQuiz,
                .practiceMode(PracticeSessionLaunch(
                    mode: .quiz,
                    wordIds: PracticeWordPool.wordIds(for: .quiz, store: store),
                    unitId: nil
                )),
                "questionmark.circle.fill"
            )
        case .flashcardsSession:
            return (
                "Complete a Flashcards session",
                1,
                ASLStarEconomy.dailyPracticeFlashcards,
                .practiceMode(PracticeSessionLaunch(
                    mode: .flashcards,
                    wordIds: PracticeWordPool.wordIds(for: .flashcards, store: store),
                    unitId: nil
                )),
                "rectangle.on.rectangle.angled.fill"
            )
        case .spellYourNameSession:
            return (
                "Spell your name",
                1,
                ASLStarEconomy.dailyPracticeSpellYourName,
                .practiceMode(PracticeSessionLaunch(
                    mode: .spellYourName,
                    wordIds: [],
                    unitId: nil
                )),
                "person.text.rectangle.fill"
            )
        case .finishUnit:
            let unitTitle = spec.params["unitTitle"] ?? "your unit"
            return (
                "Finish the \(unitTitle) unit",
                1,
                ASLStarEconomy.dailyPracticeFinishUnit,
                .homePath,
                "book.fill"
            )
        case .dictionaryCategory:
            let title = spec.params["categoryTitle"] ?? "the dictionary"
            let categoryId = spec.params["categoryId"] ?? ""
            return (
                "Study 2 signs from \(title)",
                2,
                ASLStarEconomy.dailyPracticeDictionaryCategory,
                .signsCategory(categoryId: categoryId),
                "books.vertical.fill"
            )
        case .dictionaryFavorites:
            return (
                "Review 3 favorited signs",
                3,
                ASLStarEconomy.dailyPracticeDictionaryFavorites,
                .signsFavorites,
                "heart.fill"
            )
        case .quizCorrectCount:
            return (
                "Get 5 correct in Quiz",
                5,
                ASLStarEconomy.dailyPracticeQuizCorrect,
                .practiceMode(PracticeSessionLaunch(
                    mode: .quiz,
                    wordIds: PracticeWordPool.wordIds(for: .quiz, store: store),
                    unitId: nil
                )),
                "flame.fill"
            )
        case .weakSignsQuiz:
            let wordIds = (spec.params["wordIds"] ?? "")
                .split(separator: ",")
                .map(String.init)
            let unitId = spec.params["unitId"]
            return (
                "Practice 3 signs you missed",
                3,
                ASLStarEconomy.dailyPracticeWeakSigns,
                .practiceMode(PracticeSessionLaunch(
                    mode: .quiz,
                    wordIds: wordIds,
                    unitId: unitId
                )),
                "arrow.counterclockwise.circle.fill"
            )
        }
    }
}
