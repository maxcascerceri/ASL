//
//  PracticePathContext.swift
//  ASL
//

import Foundation

enum PracticePathContext {
    static func primaryUnits(from store: ASLDataStore) -> [ASLUnit] {
        guard let pathId = store.paths.first?.id else { return [] }
        return (store.unitsByPathId[pathId] ?? [])
            .filter { !$0.isReview }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func currentLearningUnit(from store: ASLDataStore) -> ASLUnit? {
        primaryUnits(from: store).first { !store.isUnitComplete($0) }
    }

    static func lastCompletedUnit(from store: ASLDataStore) -> ASLUnit? {
        primaryUnits(from: store).last { store.isUnitComplete($0) }
    }

    static func wordIds(forUnitId unitId: String, store: ASLDataStore) -> [String] {
        var ids = Set<String>()
        if let lessons = store.lessonsByUnitId[unitId] {
            for lesson in lessons {
                ids.formUnion(lesson.wordIds)
            }
        }
        return ids.sorted {
            ASLWordDisplay.title(for: $0).localizedCaseInsensitiveCompare(
                ASLWordDisplay.title(for: $1)
            ) == .orderedAscending
        }
    }

    static func unitIndex(for unit: ASLUnit, store: ASLDataStore) -> Int? {
        primaryUnits(from: store).firstIndex { $0.id == unit.id }
    }
}
