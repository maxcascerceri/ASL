import Foundation

/// Maps English gloss aliases that share one ASL production to canonical playback ids.
enum SignEquivalence {
    private static let aliasToCanonical: [String: String] = [
        "me": "i",
        "us": "we",
        "him": "he",
        "her": "she",
        "them": "they",
        "mine": "my",
        "yours": "your",
        "ours": "our",
    ]

    private static let groupedTitles: [String: String] = [
        "i": "I / Me",
        "we": "We / Us",
        "he": "He / Him",
        "she": "She / Her",
        "they": "They / Them",
        "my": "My / Mine",
        "your": "Your / Yours",
        "our": "Our / Ours",
    ]

    /// Ordered primary ids for the pronouns dictionary category (11 cells).
    static let pronounGridWordIds: [String] = [
        "i", "you", "we", "he", "she", "they",
        "my", "your", "our", "his", "their",
    ]

    static func canonicalSignId(for wordId: String) -> String {
        aliasToCanonical[wordId] ?? wordId
    }

    static func isAlias(_ wordId: String) -> Bool {
        aliasToCanonical[wordId] != nil
    }

    static func groupedDisplayTitle(for wordId: String) -> String? {
        let canonical = canonicalSignId(for: wordId)
        return groupedTitles[canonical]
    }

    static func dictionaryTitle(for wordId: String, fallback: String) -> String {
        groupedDisplayTitle(for: wordId) ?? fallback
    }

    /// Search matches primary or alias gloss (e.g. "him" finds the He / Him group).
    static func matchesSearchQuery(_ wordId: String, query: String) -> Bool {
        let lowered = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return true }

        let canonical = canonicalSignId(for: wordId)
        let candidates = Set([wordId, canonical] + aliases(forCanonical: canonical))
        return candidates.contains { candidate in
            ASLWordDisplay.title(for: candidate).lowercased().hasPrefix(lowered)
        }
    }

    static func aliases(forCanonical canonical: String) -> [String] {
        aliasToCanonical.compactMap { alias, target in
            target == canonical ? alias : nil
        }
    }

    /// Detail sheet swipe order: primary id plus alias glosses when grouped.
    static func dictionaryDetailWordIds(primaryWordId: String) -> [String] {
        let canonical = canonicalSignId(for: primaryWordId)
        let aliases = aliases(forCanonical: canonical)
        if aliases.isEmpty {
            return [canonical]
        }
        return [canonical] + aliases.sorted()
    }
}
