//
//  PracticeWordPool.swift
//  ASL
//

import Foundation

enum PracticeWordPool {
    /// Completed lesson vocabulary from reachable home-path units (Sign Sprint / Memory Challenge).
    static func pathLearnedWordIds(from store: ASLDataStore) -> [String] {
        var ids = Set<String>()
        let letterIds = Set(PracticeAlphabet.letterWordIds)

        for unit in reachableUnits(from: store) {
            ids.formUnion(completedWordIds(in: unit, store: store, excluding: letterIds))
        }

        return sortedWordIds(ids)
    }

    /// Legacy broad pool — dictionary study and all loaded lessons (alphabet fallback only).
    static func learnedWordIds(from store: ASLDataStore) -> [String] {
        var ids = Set(pathLearnedWordIds(from: store))

        if ids.isEmpty {
            ids.formUnion(letterIdsFromAlphabetLessonProgress(store))
        }

        return sortedWordIds(ids)
    }

    /// Full A–Z deck for alphabet matching (always available on the practice hub).
    static func alphabetWordIds(from store: ASLDataStore) -> [String] {
        var ids = Set(PracticeAlphabet.letterWordIds)

        let learnedLetters = pathLearnedWordIds(from: store).filter {
            PracticeAlphabet.letterWordIds.contains($0)
        }
        ids.formUnion(learnedLetters)
        ids.formUnion(letterIdsFromAlphabetUnits(store))

        return PracticeAlphabet.letterWordIds.filter { ids.contains($0) }
    }

    static func wordIds(for mode: PracticeMode, store: ASLDataStore) -> [String] {
        switch mode {
        case .quiz:
            return quizWordIds(from: store)
        case .flashcards:
            return flashcardsWordIds(from: store)
        case .vocabularyMatch:
            return vocabularyMatchWordIds(from: store)
        case .spellYourName:
            return PracticeWordPool.alphabetWordIds(from: store)
        }
    }

    static func isVocabularyMatchAvailable(from store: ASLDataStore) -> Bool {
        vocabularyMatchWordIds(from: store).count >= PracticeMode.vocabularyMatch.minimumWordCount
    }

    /// Daily quiz rotation — requires 20+ learned signs.
    static func quizWordIds(from store: ASLDataStore) -> [String] {
        guard isQuizAvailable(from: store) else { return [] }
        return PracticeQuizCatalog.sessionWordIds(from: store)
    }

    static func isQuizAvailable(from store: ASLDataStore) -> Bool {
        PracticeQuizCatalog.isAvailable(from: store)
    }

    /// Learned path vocabulary for Vocabulary Match (up to 20 signs, day-seeded).
    static func vocabularyMatchWordIds(from store: ASLDataStore) -> [String] {
        let learned = pathLearnedWordIds(from: store)
        guard learned.count >= PracticeMode.vocabularyMatch.minimumWordCount else { return [] }

        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64("vocab-match:\(ProfileDayKey.today())")
        )
        let shuffled = learned.shuffled(using: &generator)
        return Array(shuffled.prefix(min(20, shuffled.count)))
    }

    /// Full learned vocabulary for flashcards (same pool as legacy memory challenge).
    static func flashcardsWordIds(from store: ASLDataStore) -> [String] {
        signAndMemoryWordIds(from: store)
    }

    private static func signAndMemoryWordIds(from store: ASLDataStore) -> [String] {
        let letterIds = Set(PracticeAlphabet.letterWordIds)
        var ids = Set(pathLearnedWordIds(from: store))

        if ids.count < modeMinimumWordCount {
            for unit in reachableUnits(from: store) {
                let unitWords = PracticePathContext.wordIds(forUnitId: unit.id, store: store)
                    .filter { !letterIds.contains($0) }
                ids.formUnion(unitWords)
            }
        }

        return sortedWordIds(ids)
    }

    private static let modeMinimumWordCount = 4

    // MARK: - Path scope

    /// Units the learner has reached on the primary home path.
    static func reachableUnits(from store: ASLDataStore) -> [ASLUnit] {
        let units = PracticePathContext.primaryUnits(from: store)
        if let currentIndex = units.firstIndex(where: { !store.isUnitComplete($0) }) {
            return Array(units.prefix(through: currentIndex))
        }
        return units
    }

    private static func completedWordIds(
        in unit: ASLUnit,
        store: ASLDataStore,
        excluding letterIds: Set<String>
    ) -> Set<String> {
        var ids = Set<String>()

        if let lessons = store.lessonsByUnitId[unit.id], !lessons.isEmpty {
            for lesson in lessons where store.lessonProgress(for: lesson.id) >= 1 {
                ids.formUnion(lesson.wordIds.filter { !letterIds.contains($0) })
            }
            return ids
        }

        return ids
    }

    // MARK: - Alphabet units (p1-u10 … p1-u13)

    private static func letterIdsFromAlphabetUnits(_ store: ASLDataStore) -> Set<String> {
        var ids = Set<String>()

        for unitId in PracticeAlphabet.unitIds {
            guard alphabetUnitContributesLetters(unitId: unitId, store: store) else { continue }
            if let letters = PracticeAlphabet.lettersByUnitId[unitId] {
                ids.formUnion(letters)
            }
        }

        return ids
    }

    /// Include a unit's letter set when the learner has unlocked, started, or finished it.
    private static func alphabetUnitContributesLetters(unitId: String, store: ASLDataStore) -> Bool {
        if let unit = alphabetUnit(unitId: unitId, store: store) {
            if store.isUnitComplete(unit) { return true }
            if hasStarted(unit: unit, store: store) { return true }
            if isUnlockedOnPath(unit: unit, store: store) { return true }
        }

        return hasStartedAlphabetUnit(unitId: unitId, store: store)
    }

    private static func letterIdsFromAlphabetLessonProgress(_ store: ASLDataStore) -> Set<String> {
        var ids = Set<String>()
        for unitId in PracticeAlphabet.unitIds {
            guard let lessons = store.lessonsByUnitId[unitId] else { continue }
            for lesson in lessons where store.lessonProgress(for: lesson.id) > 0 {
                ids.formUnion(lesson.wordIds.filter { PracticeAlphabet.letterWordIds.contains($0) })
            }
        }
        return ids
    }

    private static func hasStartedAlphabetUnit(unitId: String, store: ASLDataStore) -> Bool {
        if let lessons = store.lessonsByUnitId[unitId], !lessons.isEmpty {
            return lessons.contains { store.lessonProgress(for: $0.id) > 0 }
        }
        return (1...3).contains { index in
            store.lessonProgress(for: "\(unitId)-l\(index)") > 0
        }
    }

    private static func hasStarted(unit: ASLUnit, store: ASLDataStore) -> Bool {
        hasStartedAlphabetUnit(unitId: unit.id, store: store)
    }

    private static func alphabetUnit(unitId: String, store: ASLDataStore) -> ASLUnit? {
        for units in store.unitsByPathId.values {
            if let unit = units.first(where: { $0.id == unitId }) {
                return unit
            }
        }
        return nil
    }

    /// Same rule as the home path: units up to the current learning unit are reachable.
    private static func isUnlockedOnPath(unit: ASLUnit, store: ASLDataStore) -> Bool {
        guard let pathUnits = store.unitsByPathId[unit.pathId]?
            .filter({ !$0.isReview })
            .sorted(by: { $0.sortOrder < $1.sortOrder }),
              let unitIndex = pathUnits.firstIndex(where: { $0.id == unit.id })
        else { return false }

        if let currentIndex = pathUnits.firstIndex(where: { !store.isUnitComplete($0) }) {
            return unitIndex <= currentIndex
        }

        return true
    }

    private static func sortedWordIds(_ ids: Set<String>) -> [String] {
        ids.sorted {
            ASLWordDisplay.title(for: $0).localizedCaseInsensitiveCompare(
                ASLWordDisplay.title(for: $1)
            ) == .orderedAscending
        }
    }
}
