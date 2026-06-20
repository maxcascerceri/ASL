//
//  FingerspellNameStore.swift
//  ASL
//

import Foundation

struct SavedFingerspellEntry: Codable, Equatable, Identifiable, Hashable {
    let id: String
    var displayText: String
    var spellingText: String
    var letterWordIds: [String]
    var intent: FingerspellNameIntent
    var isPinned: Bool
    var createdAt: TimeInterval
    var practiceCount: Int

    var letterCount: Int { letterWordIds.count }
}

enum FingerspellNameStore {
    private static let storageKey = "asl.fingerspell.entries.v1"
    private static let maxEntries = 10

    static func allEntries() -> [SavedFingerspellEntry] {
        load().sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            if lhs.practiceCount != rhs.practiceCount { return lhs.practiceCount > rhs.practiceCount }
            return lhs.createdAt > rhs.createdAt
        }
    }

    static func pinnedEntry() -> SavedFingerspellEntry? {
        allEntries().first(where: \.isPinned)
    }

    static func lastPracticedEntry() -> SavedFingerspellEntry? {
        allEntries().max { $0.practiceCount == $1.practiceCount
            ? $0.createdAt < $1.createdAt
            : $0.practiceCount < $1.practiceCount
        }
    }

    static func entry(id: String) -> SavedFingerspellEntry? {
        load().first { $0.id == id }
    }

    @discardableResult
    static func save(_ entry: SavedFingerspellEntry) -> SavedFingerspellEntry {
        var entries = load()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            if entries.count >= maxEntries {
                if let removable = entries
                    .filter({ !$0.isPinned })
                    .min(by: { $0.practiceCount == $1.practiceCount
                        ? $0.createdAt < $1.createdAt
                        : $0.practiceCount < $1.practiceCount
                    }) {
                    entries.removeAll { $0.id == removable.id }
                }
            }
            entries.append(entry)
        }
        persist(entries)
        return entry
    }

    static func recordPractice(for entryId: String) {
        var entries = load()
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].practiceCount += 1
        persist(entries)
    }

    static func delete(id: String) {
        var entries = load()
        entries.removeAll { $0.id == id }
        persist(entries)
    }

    static func setPinned(id: String) {
        var entries = load()
        for index in entries.indices {
            entries[index].isPinned = entries[index].id == id
        }
        persist(entries)
    }

    private static func load() -> [SavedFingerspellEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedFingerspellEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private static func persist(_ entries: [SavedFingerspellEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
