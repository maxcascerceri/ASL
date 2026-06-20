//
//  PracticeOption.swift
//  ASL
//

import Foundation

enum PracticeMode: String, CaseIterable, Identifiable, Hashable {
    case quiz
    case flashcards
    case vocabularyMatch
    case spellYourName

    var id: String { rawValue }

    /// Legacy raw value for medal / progress migration.
    static let legacyAlphabetMatchingRawValue = "alphabetMatching"

    var title: String {
        switch self {
        case .quiz: return "Daily Quiz"
        case .flashcards: return "Flashcards"
        case .vocabularyMatch: return "Vocabulary Match"
        case .spellYourName: return "Spell Your Name"
        }
    }

    var subtitle: String {
        switch self {
        case .quiz:
            return "Mixed review — watch, translate, and pick the sign"
        case .flashcards:
            return "Flip through signs at your own pace"
        case .vocabularyMatch:
            return "Match signs you've learned to their words"
        case .spellYourName:
            return "Type a name and practice fingerspelling it letter by letter"
        }
    }

    var minimumWordCount: Int {
        switch self {
        case .quiz: return 20
        case .vocabularyMatch: return 8
        case .flashcards, .spellYourName: return 4
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .quiz:
            return "Learn at least 20 signs on the home path to unlock Daily Quiz."
        case .vocabularyMatch:
            return "Learn at least 8 signs on the home path to unlock Vocabulary Match."
        case .spellYourName:
            return "Reach The Alphabet on the home path, or finish a few alphabet lessons, to unlock Spell Your Name."
        default:
            return "Finish a lesson or study signs in the dictionary first."
        }
    }
}

struct PracticeSessionLaunch: Equatable, Hashable, Identifiable {
    let mode: PracticeMode
    let wordIds: [String]
    let unitId: String?
    let spellEntry: SavedFingerspellEntry?
    let spellIntent: FingerspellNameIntent?

    init(
        mode: PracticeMode,
        wordIds: [String],
        unitId: String? = nil,
        spellEntry: SavedFingerspellEntry? = nil,
        spellIntent: FingerspellNameIntent? = nil
    ) {
        self.mode = mode
        self.wordIds = wordIds
        self.unitId = unitId
        self.spellEntry = spellEntry
        self.spellIntent = spellIntent
    }

    var id: String {
        if let spellEntry {
            return "\(mode.rawValue)-spell-\(spellEntry.id)"
        }
        return "\(mode.rawValue)-\(unitId ?? "all")-\(wordIds.hashValue)"
    }
}

enum PracticeAlphabet {
    /// Home path alphabet unit (`p1-u10` The Alphabet).
    static let unitIds = ["p1-u10"]

    static let letterWordIds: [String] = [
        "a", "b", "c", "d", "e", "f", "g", "h", "letteri", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
    ]

    static let lettersByUnitId: [String: [String]] = [
        "p1-u10": letterWordIds
    ]
}

enum PracticeSpellYourNameAvailability {
    static func isUnlocked(from store: ASLDataStore) -> Bool {
        !PracticeWordPool.alphabetWordIds(from: store).isEmpty
    }
}
