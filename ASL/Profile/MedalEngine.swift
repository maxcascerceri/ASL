//
//  MedalEngine.swift
//  ASL
//

import Combine
import Foundation

struct AchievementProgressSnapshot: Codable {
    var unlockedMedalIds: [String]
    var pendingCelebrationMedalIds: [String]
    var practiceSessionCountByMode: [String: Int]
    var totalPracticeSessions: Int
    var practiceModesEverCompleted: [String]
    var inLessonStreakMilestonesHit: Int
    var didMigrateExistingProgress: Bool
    var medalCatalogVersion: Int
    var deferredUntilHome: Bool

    enum CodingKeys: String, CodingKey {
        case unlockedMedalIds
        case pendingCelebrationMedalIds
        case practiceSessionCountByMode
        case totalPracticeSessions
        case practiceModesEverCompleted
        case inLessonStreakMilestonesHit
        case didMigrateExistingProgress
        case medalCatalogVersion
        case deferredUntilHome
    }

    init(
        unlockedMedalIds: [String],
        pendingCelebrationMedalIds: [String],
        practiceSessionCountByMode: [String: Int],
        totalPracticeSessions: Int,
        practiceModesEverCompleted: [String],
        inLessonStreakMilestonesHit: Int,
        didMigrateExistingProgress: Bool,
        medalCatalogVersion: Int,
        deferredUntilHome: Bool
    ) {
        self.unlockedMedalIds = unlockedMedalIds
        self.pendingCelebrationMedalIds = pendingCelebrationMedalIds
        self.practiceSessionCountByMode = practiceSessionCountByMode
        self.totalPracticeSessions = totalPracticeSessions
        self.practiceModesEverCompleted = practiceModesEverCompleted
        self.inLessonStreakMilestonesHit = inLessonStreakMilestonesHit
        self.didMigrateExistingProgress = didMigrateExistingProgress
        self.medalCatalogVersion = medalCatalogVersion
        self.deferredUntilHome = deferredUntilHome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlockedMedalIds = try container.decode([String].self, forKey: .unlockedMedalIds)
        pendingCelebrationMedalIds = try container.decode([String].self, forKey: .pendingCelebrationMedalIds)
        practiceSessionCountByMode = try container.decode([String: Int].self, forKey: .practiceSessionCountByMode)
        totalPracticeSessions = try container.decode(Int.self, forKey: .totalPracticeSessions)
        practiceModesEverCompleted = try container.decode([String].self, forKey: .practiceModesEverCompleted)
        inLessonStreakMilestonesHit = try container.decode(Int.self, forKey: .inLessonStreakMilestonesHit)
        didMigrateExistingProgress = try container.decode(Bool.self, forKey: .didMigrateExistingProgress)
        medalCatalogVersion = try container.decodeIfPresent(Int.self, forKey: .medalCatalogVersion) ?? 0
        deferredUntilHome = try container.decodeIfPresent(Bool.self, forKey: .deferredUntilHome) ?? false
    }

    static func fresh() -> AchievementProgressSnapshot {
        AchievementProgressSnapshot(
            unlockedMedalIds: [],
            pendingCelebrationMedalIds: [],
            practiceSessionCountByMode: [:],
            totalPracticeSessions: 0,
            practiceModesEverCompleted: [],
            inLessonStreakMilestonesHit: 0,
            didMigrateExistingProgress: false,
            medalCatalogVersion: 0,
            deferredUntilHome: false
        )
    }
}

@MainActor
final class MedalEngine: ObservableObject {
    @Published private(set) var snapshot: AchievementProgressSnapshot

    private let storageKey = "asl.achievementProgress.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AchievementProgressSnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = .fresh()
        }
        migrateSpellYourNamePracticeProgressIfNeeded()
    }

    // MARK: - Public API

    func allMedals(from store: ASLDataStore) -> [ProfileMedalItem] {
        let unlocked = Set(snapshot.unlockedMedalIds)
        return ASLMedalCatalog.allDefinitions(from: store).map { definition in
            let isEarned = unlocked.contains(definition.id)
            return ProfileMedalItem(
                definition: definition,
                state: isEarned ? .earned : .locked,
                progressFraction: isEarned ? 1 : progressFraction(for: definition, store: store)
            )
        }
    }

    func earnedCount(from store: ASLDataStore) -> Int {
        allMedals(from: store).filter(\.isUnlocked).count
    }

    func medalsGrouped(from store: ASLDataStore) -> [MedalSection] {
        let items = allMedals(from: store)
        var sections: [MedalSection] = []
        var sectionBuildOrder = 0
        var sectionOrderIndex: [String: Int] = [:]

        for phase in ASLMedalCatalog.phaseOrder {
            let phaseItems = ASLMedalCatalog.gridAligned(
                items.filter {
                    $0.definition.category == .learningPath && $0.definition.phaseKey == phase.key
                }
            )
            guard !phaseItems.isEmpty else { continue }
            let sectionId = "phase:\(phase.key)"
            sectionOrderIndex[sectionId] = sectionBuildOrder
            sectionBuildOrder += 1
            sections.append(MedalSection(
                id: sectionId,
                title: phase.title,
                subtitle: "\(phaseItems.filter(\.isUnlocked).count)/\(phaseItems.count) earned",
                category: .learningPath,
                phaseKey: phase.key,
                items: sortedSectionItems(phaseItems)
            ))
        }

        for category in MedalCategory.allCases where category != .learningPath {
            let categoryItems = ASLMedalCatalog.gridAligned(
                items.filter { $0.definition.category == category }
            )
            guard !categoryItems.isEmpty else { continue }
            let sectionId = "category:\(category.rawValue)"
            sectionOrderIndex[sectionId] = sectionBuildOrder
            sectionBuildOrder += 1
            sections.append(MedalSection(
                id: sectionId,
                title: category.displayTitle,
                subtitle: "\(categoryItems.filter(\.isUnlocked).count)/\(categoryItems.count) earned",
                category: category,
                phaseKey: nil,
                items: sortedSectionItems(categoryItems)
            ))
        }

        return sections.sorted { lhs, rhs in
            compareSections(lhs, rhs, orderIndex: sectionOrderIndex)
        }
    }

    func previewMedals(from store: ASLDataStore, limit: Int = 8) -> [ProfileMedalItem] {
        let all = allMedals(from: store)
        let eligible = all.filter {
            $0.isUnlocked || $0.progressFraction > 0 || $0.definition.fitsCompactProfileLabel
        }

        var result: [ProfileMedalItem] = []
        var usedIds = Set<String>()

        for id in snapshot.unlockedMedalIds.reversed() {
            guard result.count < limit else { break }
            guard let item = eligible.first(where: { $0.id == id && $0.isUnlocked }) else { continue }
            result.append(item)
            usedIds.insert(id)
        }

        if result.count < limit {
            let inProgress = sortedSectionItems(
                eligible.filter { !usedIds.contains($0.id) && !$0.isUnlocked && $0.progressFraction > 0 }
            )
            for item in inProgress {
                guard result.count < limit else { break }
                result.append(item)
                usedIds.insert(item.id)
            }
        }

        if result.count < limit {
            let remainder = sortedSectionItems(eligible.filter { !usedIds.contains($0.id) })
            result.append(contentsOf: remainder.prefix(limit - result.count))
        }

        return result
    }

    func progressFraction(for definition: ASLMedalDefinition, store: ASLDataStore) -> Double {
        guard let progress = progress(for: definition, store: store), progress.target > 0 else {
            return 0
        }
        return min(1, max(0, Double(progress.current) / Double(progress.target)))
    }

    func progress(for definition: ASLMedalDefinition, store: ASLDataStore) -> (current: Int, target: Int)? {
        switch definition.criterion {
        case .unitComplete:
            return nil
        case .unitsComplete(let unitIds):
            let completed = completedUnitCount(unitIds, store: store)
            return (completed, unitIds.count)
        case .dailyStreakBest(let target):
            return (store.bestDailyActivityStreak, target)
        case .totalStars(let target):
            return (store.totalStars, target)
        case .signsLearned(let target):
            return (store.learnedSignsCount, target)
        case .inLessonStreakBest(let target):
            return (store.displayStreak, target)
        case .practiceSessions(let mode, let target):
            if let mode {
                let count = snapshot.practiceSessionCountByMode[mode.rawValue, default: 0]
                return (count, target)
            }
            return (snapshot.totalPracticeSessions, target)
        case .practiceModesCompleted(let target):
            return (snapshot.practiceModesEverCompleted.count, target)
        }
    }

    func reconcile(with store: ASLDataStore) {
        let definitions = ASLMedalCatalog.allDefinitions(from: store)
        let catalogIds = Set(definitions.map(\.id))
        snapshot.unlockedMedalIds = snapshot.unlockedMedalIds.filter { catalogIds.contains($0) }
        snapshot.pendingCelebrationMedalIds = snapshot.pendingCelebrationMedalIds.filter { id in
            guard catalogIds.contains(id),
                  let definition = definitions.first(where: { $0.id == id })
            else { return false }
            return qualifiesForCelebration(definition)
        }

        let eligible = Set(definitions.filter { isEligible($0, store: store) }.map(\.id))
        let previouslyUnlocked = Set(snapshot.unlockedMedalIds)
        let pathMedalsAvailable = !ASLMedalCatalog.pathMedals(from: store).isEmpty
        let catalogVersionChanged = snapshot.medalCatalogVersion < ASLMedalCatalog.medalCatalogVersion

        if !snapshot.didMigrateExistingProgress {
            var migrated = previouslyUnlocked.union(eligible)

            if pathMedalsAvailable {
                snapshot.unlockedMedalIds = Array(migrated).sorted()
                snapshot.didMigrateExistingProgress = true
                snapshot.medalCatalogVersion = ASLMedalCatalog.medalCatalogVersion
                persist()
                return
            }

            let achievementOnly = Set(
                definitions
                    .filter { $0.category != .learningPath && isEligible($0, store: store) }
                    .map(\.id)
            )
            migrated = previouslyUnlocked.union(achievementOnly)
            snapshot.unlockedMedalIds = Array(migrated).sorted()
            snapshot.didMigrateExistingProgress = true
            snapshot.medalCatalogVersion = ASLMedalCatalog.medalCatalogVersion
            persist()
            return
        }

        if catalogVersionChanged {
            let backfill = eligible.subtracting(previouslyUnlocked)
            if !backfill.isEmpty {
                for id in backfill.sorted() where !snapshot.unlockedMedalIds.contains(id) {
                    snapshot.unlockedMedalIds.append(id)
                }
            }
            snapshot.medalCatalogVersion = ASLMedalCatalog.medalCatalogVersion
            persist()
            return
        }

        let newlyUnlocked = eligible.subtracting(previouslyUnlocked)
        guard !newlyUnlocked.isEmpty else {
            persist()
            return
        }

        for id in newlyUnlocked.sorted() {
            if !snapshot.unlockedMedalIds.contains(id) {
                snapshot.unlockedMedalIds.append(id)
            }
        }

        // Only learning-path unit medals get a celebration pop-up; everything else
        // unlocks silently and appears on the profile medals screen.
        let celebrationEligibleNew = newlyUnlocked.filter { id in
            guard let definition = definitions.first(where: { $0.id == id }) else { return false }
            return qualifiesForCelebration(definition)
        }
        let celebrationPool = Set(snapshot.pendingCelebrationMedalIds).union(celebrationEligibleNew)
        if let chosenId = preferredCelebrationMedalId(from: celebrationPool, store: store) {
            snapshot.pendingCelebrationMedalIds = [chosenId]
            if store.isLessonMediaSessionActive {
                snapshot.deferredUntilHome = true
            }
        } else {
            snapshot.pendingCelebrationMedalIds = []
            snapshot.deferredUntilHome = false
        }
        persist()
    }

    func recordPracticeSession(mode: PracticeMode) {
        snapshot.totalPracticeSessions += 1
        snapshot.practiceSessionCountByMode[mode.rawValue, default: 0] += 1
        if !snapshot.practiceModesEverCompleted.contains(mode.rawValue) {
            snapshot.practiceModesEverCompleted.append(mode.rawValue)
        }
        persist()
    }

    func recordInLessonStreakMilestone() {
        snapshot.inLessonStreakMilestonesHit += 1
        persist()
    }

    private func migrateSpellYourNamePracticeProgressIfNeeded() {
        let legacyMode = PracticeMode.legacyAlphabetMatchingRawValue
        let newMode = PracticeMode.spellYourName.rawValue
        var changed = false

        if let legacyCount = snapshot.practiceSessionCountByMode[legacyMode] {
            snapshot.practiceSessionCountByMode[newMode, default: 0] += legacyCount
            snapshot.practiceSessionCountByMode.removeValue(forKey: legacyMode)
            changed = true
        }

        if snapshot.practiceModesEverCompleted.contains(legacyMode) {
            if !snapshot.practiceModesEverCompleted.contains(newMode) {
                snapshot.practiceModesEverCompleted.append(newMode)
            }
            snapshot.practiceModesEverCompleted.removeAll { $0 == legacyMode }
            changed = true
        }

        let legacyMedal = "practice:first:\(legacyMode)"
        let newMedal = "practice:first:\(newMode)"
        if snapshot.unlockedMedalIds.contains(legacyMedal) {
            if !snapshot.unlockedMedalIds.contains(newMedal) {
                snapshot.unlockedMedalIds.append(newMedal)
            }
            changed = true
        }

        if changed {
            persist()
        }
    }

    func consumeNextCelebration(from store: ASLDataStore) -> ASLMedalDefinition? {
        guard let nextId = snapshot.pendingCelebrationMedalIds.first else { return nil }
        snapshot.pendingCelebrationMedalIds.removeFirst()
        persist()
        return ASLMedalCatalog.allDefinitions(from: store).first(where: { $0.id == nextId })
    }

    var hasPendingCelebration: Bool {
        !snapshot.pendingCelebrationMedalIds.isEmpty
    }

    var isDeferredUntilHome: Bool {
        snapshot.deferredUntilHome
    }

    func clearDeferredUntilHome() {
        guard snapshot.deferredUntilHome else { return }
        snapshot.deferredUntilHome = false
        persist()
    }

    // MARK: - Private

    private func sortedSectionItems(_ items: [ProfileMedalItem]) -> [ProfileMedalItem] {
        items.sorted { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked {
                return lhs.isUnlocked && !rhs.isUnlocked
            }
            if lhs.progressFraction != rhs.progressFraction {
                return lhs.progressFraction > rhs.progressFraction
            }
            return lhs.definition.sortOrder < rhs.definition.sortOrder
        }
    }

    private func sectionActivityScore(_ section: MedalSection) -> (totalProgress: Double, earned: Int, inProgress: Int) {
        let earned = section.earnedCount
        let totalProgress = section.items.reduce(0.0) { $0 + $1.progressFraction }
        let inProgress = section.items.filter { !$0.isUnlocked && $0.progressFraction > 0 }.count
        return (totalProgress, earned, inProgress)
    }

    private func compareSections(
        _ lhs: MedalSection,
        _ rhs: MedalSection,
        orderIndex: [String: Int]
    ) -> Bool {
        let left = sectionActivityScore(lhs)
        let right = sectionActivityScore(rhs)

        let leftActive = left.earned > 0 || left.totalProgress > 0
        let rightActive = right.earned > 0 || right.totalProgress > 0
        if leftActive != rightActive {
            return leftActive && !rightActive
        }

        if left.totalProgress != right.totalProgress {
            return left.totalProgress > right.totalProgress
        }

        if left.earned != right.earned {
            return left.earned > right.earned
        }

        if left.inProgress != right.inProgress {
            return left.inProgress > right.inProgress
        }

        let leftIndex = orderIndex[lhs.id, default: Int.max]
        let rightIndex = orderIndex[rhs.id, default: Int.max]
        return leftIndex < rightIndex
    }

    private func isEligible(_ definition: ASLMedalDefinition, store: ASLDataStore) -> Bool {
        switch definition.criterion {
        case .unitComplete(let unitId):
            guard let pathId = store.paths.first?.id,
                  let units = store.unitsByPathId[pathId],
                  let unit = units.first(where: { $0.id == unitId })
            else { return false }
            return store.isUnitComplete(unit)
        case .unitsComplete(let unitIds):
            return completedUnitCount(unitIds, store: store) >= unitIds.count
        case .dailyStreakBest(let target):
            return store.bestDailyActivityStreak >= target
        case .totalStars(let target):
            return store.totalStars >= target
        case .signsLearned(let target):
            return store.learnedSignsCount >= target
        case .inLessonStreakBest(let target):
            return store.displayStreak >= target
        case .practiceSessions(let mode, let target):
            if let mode {
                return snapshot.practiceSessionCountByMode[mode.rawValue, default: 0] >= target
            }
            return snapshot.totalPracticeSessions >= target
        case .practiceModesCompleted(let target):
            return snapshot.practiceModesEverCompleted.count >= target
        }
    }

    private func completedUnitCount(_ unitIds: [String], store: ASLDataStore) -> Int {
        guard let pathId = store.paths.first?.id,
              let units = store.unitsByPathId[pathId]
        else { return 0 }

        let unitsById = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })
        return unitIds.reduce(into: 0) { count, unitId in
            guard let unit = unitsById[unitId] else { return }
            if store.isUnitComplete(unit) {
                count += 1
            }
        }
    }

    private func qualifiesForCelebration(_ definition: ASLMedalDefinition) -> Bool {
        switch definition.criterion {
        case .unitComplete, .unitsComplete:
            return true
        case .dailyStreakBest, .totalStars, .signsLearned, .inLessonStreakBest,
             .practiceSessions, .practiceModesCompleted:
            return false
        }
    }

    /// When several medals unlock together, celebrate the highest catalog tier once.
    private func preferredCelebrationMedalId(
        from ids: Set<String>,
        store: ASLDataStore
    ) -> String? {
        ASLMedalCatalog.allDefinitions(from: store)
            .filter { ids.contains($0.id) }
            .max(by: { $0.sortOrder < $1.sortOrder })?
            .id
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        objectWillChange.send()
    }
}
