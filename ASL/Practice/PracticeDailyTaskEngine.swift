//
//  PracticeDailyTaskEngine.swift
//  ASL
//

import Combine
import Foundation

@MainActor
final class PracticeDailyTaskEngine: ObservableObject {
    @Published private(set) var tasks: [PracticeDailyTask] = []
    @Published private(set) var resetsAt: Date = ProfileDayKey.endOfToday()
    @Published private(set) var navigation = PracticeDailyNavigationCoordinator()

    private let storageKey = "asl.practiceDailyTasks.v5"
    private var snapshot: PracticeDailyTasksSnapshot
    private let awardStars: (Int, String) -> Int
    private weak var storeRef: ASLDataStore?

    init(awardStars: @escaping (Int, String) -> Int) {
        self.awardStars = awardStars
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PracticeDailyTasksSnapshot.self, from: data),
           decoded.selectedTasks.count == 3,
           !PracticeDailyPeriod.isExpired(decoded) {
            snapshot = decoded
        } else {
            snapshot = PracticeDailyPeriod.makeSnapshot(tasks: [])
        }
        publishTasks()
    }

    func bind(store: ASLDataStore) {
        storeRef = store
        refreshPeriodIfNeeded(store: store)
    }

    /// Rolls daily practice when the local calendar day changes.
    func refreshPeriodIfNeeded(store: ASLDataStore? = nil) {
        let store = store ?? storeRef
        if PracticeDailyPeriod.isExpired(snapshot) || snapshot.selectedTasks.count != 3 {
            if let store {
                let dayKey = ProfileDayKey.today()
                let selected = PracticeDailyTaskSelector.selectTasks(
                    for: dayKey,
                    store: store
                )
                snapshot = PracticeDailyPeriod.makeSnapshot(tasks: selected)
                persist()
            } else if PracticeDailyPeriod.isExpired(snapshot) {
                snapshot = PracticeDailyPeriod.makeSnapshot(tasks: [])
                persist()
            }
        }
        publishTasks(store: store)
    }

    /// Backward-compatible alias used by existing call sites.
    func refreshForToday(store: ASLDataStore? = nil) {
        refreshPeriodIfNeeded(store: store)
    }

    func recordSessionComplete(for mode: PracticeMode, unitId: String? = nil) {
        refreshPeriodIfNeeded()
        switch mode {
        case .quiz:
            incrementMatchingKinds([.quizSession])
        case .flashcards:
            incrementMatchingKinds([.flashcardsSession])
        case .vocabularyMatch:
            break
        case .spellYourName:
            incrementMatchingKinds([.spellYourNameSession])
        }
    }

    func recordQuizCorrect(wordId: String? = nil) {
        refreshPeriodIfNeeded()
        incrementTask(kind: .quizCorrectCount)
        guard let wordId, !wordId.isEmpty else { return }
        incrementTask(kind: .weakSignsQuiz, matching: { spec in
            guard let ids = spec.params["wordIds"] else { return false }
            return ids.split(separator: ",").contains(Substring(wordId))
        })
    }

    func recordUnitComplete(unitId: String) {
        refreshPeriodIfNeeded()
        incrementTask(kind: .finishUnit, matching: { $0.params["unitId"] == unitId })
    }

    func recordSignStudied(wordId: String) {
        refreshPeriodIfNeeded()
        for spec in snapshot.selectedTasks where spec.kind == .dictionaryCategory {
            if let categoryId = spec.params["categoryId"],
               let category = SignCategoryCatalog.category(withId: categoryId),
               category.wordIds.contains(wordId) {
                increment(spec: spec)
            }
        }
        if FavoriteSignsStore.contains(wordId) {
            incrementTask(kind: .dictionaryFavorites)
        }
    }

    var allTasksClaimed: Bool {
        !tasks.isEmpty && tasks.allSatisfy(\.isClaimed)
    }

    private func incrementMatchingKinds(_ kinds: [PracticeDailyTaskKind]) {
        for spec in snapshot.selectedTasks where kinds.contains(spec.kind) {
            increment(spec: spec)
        }
    }

    private func incrementTask(
        kind: PracticeDailyTaskKind,
        matching: ((PracticeDailyTaskSpec) -> Bool)? = nil
    ) {
        for spec in snapshot.selectedTasks where spec.kind == kind {
            if let matching, !matching(spec) { continue }
            increment(spec: spec)
        }
    }

    private func increment(spec: PracticeDailyTaskSpec) {
        let key = spec.instanceKey
        let current = snapshot.progressByKey[key] ?? 0
        let target = targetForSpec(spec)
        let next = min(current + 1, target)
        guard next != current else { return }
        snapshot.progressByKey[key] = next
        persist()

        if next >= target {
            tryAutoGrant(spec: spec)
            if navigation.activeTaskInstanceKey == key {
                navigation.taskCompleted(instanceKey: key)
            }
        }

        publishTasks()
    }

    private func tryAutoGrant(spec: PracticeDailyTaskSpec) {
        let key = spec.instanceKey
        guard !snapshot.claimedTaskKeys.contains(key) else { return }

        let reward = PracticeDailyTaskTemplates.starReward(for: spec)
        if reward > 0 {
            let eventId = "practiceDaily:\(key):\(snapshot.periodKey)"
            _ = awardStars(reward, eventId)
        }

        snapshot.claimedTaskKeys.append(key)
        persist()
    }

    private func targetForSpec(_ spec: PracticeDailyTaskSpec) -> Int {
        switch spec.kind {
        case .quizSession, .flashcardsSession, .spellYourNameSession, .finishUnit:
            return 1
        case .dictionaryCategory:
            return 2
        case .dictionaryFavorites:
            return 3
        case .quizCorrectCount:
            return 5
        case .weakSignsQuiz:
            return 3
        }
    }

    private func publishTasks(store: ASLDataStore? = nil) {
        if let store {
            syncFinishUnitTask(store: store)
        }
        if snapshot.selectedTasks.count != 3, let store {
            snapshot = PracticeDailyPeriod.makeSnapshot(
                tasks: PracticeDailyTaskSelector.selectTasks(
                    for: ProfileDayKey.today(),
                    store: store
                )
            )
            persist()
        }
        if let store {
            tasks = PracticeDailyTaskTemplates.tasks(from: snapshot, store: store)
        } else if let storeRef {
            tasks = PracticeDailyTaskTemplates.tasks(from: snapshot, store: storeRef)
        } else {
            tasks = []
        }
        resetsAt = ProfileDayKey.endOfToday()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Keeps finish-unit task params aligned with the learner's current home-path unit.
    private func syncFinishUnitTask(store: ASLDataStore) {
        guard let index = snapshot.selectedTasks.firstIndex(where: { $0.kind == .finishUnit }) else { return }

        let unit = PracticePathContext.currentLearningUnit(from: store)
            ?? PracticePathContext.primaryUnits(from: store).last
        guard let unit else { return }

        let updated = PracticeDailyTaskSpec(
            slot: snapshot.selectedTasks[index].slot,
            kind: .finishUnit,
            params: ["unitId": unit.id, "unitTitle": unit.title]
        )
        let existing = snapshot.selectedTasks[index]
        guard updated.instanceKey != existing.instanceKey else { return }

        if existing.kind == .finishUnit {
            let oldProgress = snapshot.progressByKey[existing.instanceKey] ?? 0
            let isClaimed = snapshot.claimedTaskKeys.contains(existing.instanceKey)
            if oldProgress >= 1 && !isClaimed { return }
        }

        snapshot.progressByKey.removeValue(forKey: existing.instanceKey)
        snapshot.claimedTaskKeys.removeAll { $0 == existing.instanceKey }
        if navigation.activeTaskInstanceKey == existing.instanceKey {
            navigation.taskCompleted(instanceKey: existing.instanceKey)
        }

        var tasks = snapshot.selectedTasks
        tasks[index] = updated
        snapshot.selectedTasks = tasks
        persist()
    }
}
