//
//  PracticeQuizCatalog.swift
//  ASL
//

import Foundation

enum PracticeQuizCatalog {
    static let rotationSize = 30
    static let minimumPoolSize = 20

    /// Temporary testing override — unlock Quiz and draw from all filmed signs.
    static let unlockForTesting = true

    private static var rotationStorageKey: String {
        unlockForTesting
            ? "asl.practice.quiz.rotation.testing.v1"
            : "asl.practice.quiz.rotation.v1"
    }

    private struct RotationSnapshot: Codable {
        let dayKey: String
        let learnedFingerprint: String
        let wordIds: [String]
    }

    static func isAvailable(from store: ASLDataStore) -> Bool {
        if unlockForTesting {
            return !eligibleWordIds(from: store).isEmpty
        }
        return eligibleWordIds(from: store).count >= minimumPoolSize
    }

    /// Learned lesson vocabulary eligible for Quiz (non-letter signs).
    /// When `unlockForTesting` is on, uses the full filmed sign catalog instead.
    static func eligibleWordIds(from store: ASLDataStore) -> [String] {
        let letterIds = Set(PracticeAlphabet.letterWordIds)
        if unlockForTesting {
            return sortedFilmedWordIds(excluding: letterIds)
        }
        return store.learnedLessonWordIds(excluding: letterIds)
    }

    /// Daily rotation used for quiz gameplay. Returns an empty array when the
    /// learner hasn't reached the 20-sign minimum (unless testing unlock is on).
    static func rotationWordIds(from store: ASLDataStore, date: Date = .now) -> [String] {
        let eligible = eligibleWordIds(from: store)
        guard unlockForTesting || eligible.count >= minimumPoolSize else { return [] }

        let dayKey = dayKey(for: date)
        let fingerprint = fingerprint(for: eligible)

        if let cached = loadRotation(),
           cached.dayKey == dayKey,
           cached.learnedFingerprint == fingerprint {
            return cached.wordIds
        }

        let rotation = computeRotation(from: eligible, dayKey: dayKey, fingerprint: fingerprint)
        saveRotation(
            RotationSnapshot(dayKey: dayKey, learnedFingerprint: fingerprint, wordIds: rotation)
        )
        return rotation
    }

    /// Words used inside a Quiz session (same as the daily rotation).
    static func sessionWordIds(from store: ASLDataStore) -> [String] {
        rotationWordIds(from: store)
    }

    static let priorityPreloadCount = 8

    static func priorityWordIds(from store: ASLDataStore) -> [String] {
        let rotation = rotationWordIds(from: store)
        return Array(rotation.prefix(priorityPreloadCount))
    }

    static func invalidateRotation() {
        UserDefaults.standard.removeObject(forKey: rotationStorageKey)
    }

    // MARK: - Rotation

    private static func computeRotation(
        from eligible: [String],
        dayKey: String,
        fingerprint: String
    ) -> [String] {
        var generator = SeededRandomNumberGenerator(seed: rotationSeed(dayKey: dayKey, fingerprint: fingerprint))
        let shuffled = eligible.shuffled(using: &generator)
        return Array(shuffled.prefix(min(rotationSize, shuffled.count)))
    }

    private static func rotationSeed(dayKey: String, fingerprint: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in "\(dayKey)|\(fingerprint)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private static func fingerprint(for wordIds: [String]) -> String {
        wordIds.joined(separator: "|")
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func loadRotation() -> RotationSnapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: rotationStorageKey),
            let snapshot = try? JSONDecoder().decode(RotationSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    private static func saveRotation(_ snapshot: RotationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: rotationStorageKey)
    }

    private static func sortedFilmedWordIds(excluding letterIds: Set<String>) -> [String] {
        FilmedSignCatalog.wordIds
            .filter { !letterIds.contains($0) }
            .sorted {
                ASLWordDisplay.title(for: $0).localizedCaseInsensitiveCompare(
                    ASLWordDisplay.title(for: $1)
                ) == .orderedAscending
            }
    }
}
