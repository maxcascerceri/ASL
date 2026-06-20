import Foundation

struct StoneMistakeEntry: Codable, Equatable {
    let wordId: String
    let sourceStoneSortOrder: Int
    let recordedAt: Date
}

/// Per-unit queue of first-pass misses for spaced repetition in later stones.
enum ASLStoneMistakeMemory {
    private static let storageKey = "asl.stoneMistakeMemory.v1"

    static func recordMiss(unitId: String, wordId: String, stoneSortOrder: Int) {
        guard !wordId.isEmpty else { return }
        var queues = loadQueues()
        var queue = queues[unitId] ?? []
        queue.removeAll { $0.wordId == wordId }
        queue.append(
            StoneMistakeEntry(
                wordId: wordId,
                sourceStoneSortOrder: stoneSortOrder,
                recordedAt: Date()
            )
        )
        queues[unitId] = queue
        saveQueues(queues)
    }

    static func peekCarryover(unitId: String, targetStoneSortOrder: Int) -> String? {
        guard targetStoneSortOrder >= 2 else { return nil }
        return loadQueues()[unitId]?.first?.wordId
    }

    static func peekQueue(unitId: String, maxCount: Int) -> [String] {
        guard maxCount > 0 else { return [] }
        guard let queue = loadQueues()[unitId] else { return [] }
        return queue.prefix(maxCount).map(\.wordId)
    }

    static func consumeCarryover(unitId: String, wordId: String) {
        var queues = loadQueues()
        guard var queue = queues[unitId] else { return }
        if let index = queue.firstIndex(where: { $0.wordId == wordId }) {
            queue.remove(at: index)
        }
        if queue.isEmpty {
            queues.removeValue(forKey: unitId)
        } else {
            queues[unitId] = queue
        }
        saveQueues(queues)
    }

    static func clearUnit(_ unitId: String) {
        var queues = loadQueues()
        queues.removeValue(forKey: unitId)
        saveQueues(queues)
    }

    private static func loadQueues() -> [String: [StoneMistakeEntry]] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode([String: [StoneMistakeEntry]].self, from: data)
        else { return [:] }
        return stored
    }

    private static func saveQueues(_ queues: [String: [StoneMistakeEntry]]) {
        if let data = try? JSONEncoder().encode(queues) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

/// One-time migration for curriculum v6 (3-stone model + path cleanup).
enum CurriculumThreeStoneMigration {
    private static let migrationDoneKey = "asl.curriculumMigration.v7.done"

    static func migrateIfNeeded(
        progressStorageKey: String,
        completedUnitsStorageKey: String
    ) {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }
        UserDefaults.standard.removeObject(forKey: progressStorageKey)
        UserDefaults.standard.removeObject(forKey: "asl.stoneMistakeMemory.v1")
        UserDefaults.standard.removeObject(forKey: completedUnitsStorageKey)
        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }
}

/// One-time migration for curriculum v5.3 (37-unit consolidation).
enum CurriculumUnitMigration {
    private static let migrationDoneKey = "asl.curriculumMigration.v6.done"
    private static let moduleStoneCount = 3

    /// Retired home-path unit id → surviving merged unit id.
    static let mergedInto: [String: String] = [
        "p1-u12": "p1-u10",
        "p1-u26": "p1-u24",
        "p1-u39": "p1-u40",
        "p1-u47": "p1-u06",
        "p1-u52": "p1-u50",
    ]

    /// Survivor unit id → all source unit ids (including the survivor).
    static let mergeGroups: [String: [String]] = [
        "p1-u10": ["p1-u10", "p1-u12"],
        "p1-u24": ["p1-u24", "p1-u26"],
        "p1-u40": ["p1-u40", "p1-u39"],
        "p1-u06": ["p1-u06", "p1-u47"],
        "p1-u50": ["p1-u50", "p1-u52"],
    ]

    struct LessonProgressSnapshot: Codable {
        var progress: Double
        var stepIndex: Int
    }

    static func migrateLessonProgressIfNeeded(progressStorageKey: String) {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        guard
            let data = UserDefaults.standard.data(forKey: progressStorageKey),
            var stored = try? JSONDecoder().decode([String: LessonProgressSnapshot].self, from: data)
        else {
            remapStoneMistakeMemory()
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        applyMergeCompletionRules(to: &stored)

        let retiredIds = Set(mergedInto.keys)
        stored = stored.filter { lessonId, _ in
            guard let unitId = unitId(fromLessonId: lessonId) else { return true }
            return !retiredIds.contains(unitId)
        }

        if let encoded = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(encoded, forKey: progressStorageKey)
        }

        remapStoneMistakeMemory()
        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }

    private static func applyMergeCompletionRules(to stored: inout [String: LessonProgressSnapshot]) {
        for (survivorId, sourceIds) in mergeGroups {
            let allSourcesComplete = sourceIds.allSatisfy { unitLessonsComplete($0, in: stored) }
            guard allSourcesComplete else { continue }
            for stone in 1...moduleStoneCount {
                let lessonId = "\(survivorId)-l\(stone)"
                stored[lessonId] = LessonProgressSnapshot(progress: 1, stepIndex: 0)
            }
        }
    }

    private static func unitLessonsComplete(
        _ unitId: String,
        in stored: [String: LessonProgressSnapshot]
    ) -> Bool {
        (1...moduleStoneCount).allSatisfy { stone in
            stored["\(unitId)-l\(stone)"]?.progress ?? 0 >= 1
        }
    }

    private static func unitId(fromLessonId lessonId: String) -> String? {
        guard let range = lessonId.range(of: "-l", options: .backwards) else { return nil }
        let prefix = lessonId[..<range.lowerBound]
        return prefix.isEmpty ? nil : String(prefix)
    }

    private static func remapStoneMistakeMemory() {
        let storageKey = "asl.stoneMistakeMemory.v1"
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            var queues = try? JSONDecoder().decode([String: [StoneMistakeEntry]].self, from: data)
        else { return }

        for (retiredId, survivorId) in mergedInto {
            guard let retiredQueue = queues.removeValue(forKey: retiredId), !retiredQueue.isEmpty else { continue }
            var survivorQueue = queues[survivorId] ?? []
            for entry in retiredQueue where !survivorQueue.contains(where: { $0.wordId == entry.wordId }) {
                survivorQueue.append(entry)
            }
            queues[survivorId] = survivorQueue
        }

        if let encoded = try? JSONEncoder().encode(queues) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
