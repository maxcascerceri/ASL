//
//  CurriculumAwareSpellingResolver.swift
//  ASL
//

import Foundation

enum FingerspellNameIntent: String, Codable, CaseIterable, Identifiable {
    case personalName
    case someoneName
    case somethingElse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personalName: return "My name"
        case .someoneName: return "Someone's name"
        case .somethingElse: return "Something else"
        }
    }

    var isNameIntent: Bool {
        self == .personalName || self == .someoneName
    }
}

enum SpellingInputClassification: Equatable {
    case personalName(displayText: String, spellingText: String, letterWordIds: [String])
    case properNoun(displayText: String, spellingText: String, letterWordIds: [String])
    case curriculumWord(wordId: String, displayText: String)
    case acronym(wordId: String, displayText: String)
    case unknown(displayText: String, spellingText: String, letterWordIds: [String])

    var displayText: String {
        switch self {
        case .personalName(let display, _, _),
             .properNoun(let display, _, _),
             .curriculumWord(_, let display),
             .acronym(_, let display),
             .unknown(let display, _, _):
            return display
        }
    }

    var letterWordIds: [String]? {
        switch self {
        case .personalName(_, _, let ids),
             .properNoun(_, _, let ids),
             .unknown(_, _, let ids):
            return ids
        case .curriculumWord, .acronym:
            return nil
        }
    }
}

enum SpellingResolveError: LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message): return message
        }
    }
}

enum CurriculumAwareSpellingResolver {
    static let blockedLexicalWordIds: Set<String> = {
        var ids = Set(PracticeAlphabet.letterWordIds)
        ids.formUnion(["alphabet", "fingerspell", "letter", "language", "word", "name", "i"])
        return ids
    }()

    private static let aliasToWordId: [String: String] = [
        "mom": "mother",
        "mum": "mother",
        "dad": "father",
        "pa": "father",
        "ma": "mother",
        "tv": "tv",
    ]

    private static let acronymMaxLength = 4

    static func resolve(
        displayText: String,
        intent: FingerspellNameIntent,
        store: ASLDataStore
    ) -> Result<SpellingInputClassification, SpellingResolveError> {
        let trimmed = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = FingerspellLetterMapper.validationMessage(for: trimmed) {
            return .failure(.validation(message))
        }

        let spellingText = FingerspellLetterMapper.normalizedSpellingString(from: trimmed)
        guard let letterWordIds = FingerspellLetterMapper.wordIds(for: spellingText) else {
            return .failure(.validation("Use A–Z letters only for now."))
        }

        let formattedDisplay = formatDisplayName(trimmed)

        if intent.isNameIntent {
            return .success(.personalName(
                displayText: formattedDisplay,
                spellingText: spellingText,
                letterWordIds: letterWordIds
            ))
        }

        if intent == .somethingElse {
            if let wordId = curriculumWordId(for: spellingText, store: store) {
                if spellingText.count <= acronymMaxLength {
                    return .success(.acronym(wordId: wordId, displayText: formattedDisplay))
                }
                return .success(.curriculumWord(wordId: wordId, displayText: formattedDisplay))
            }
            return .success(.unknown(
                displayText: formattedDisplay,
                spellingText: spellingText,
                letterWordIds: letterWordIds
            ))
        }

        return .success(.properNoun(
            displayText: formattedDisplay,
            spellingText: spellingText,
            letterWordIds: letterWordIds
        ))
    }

    static func makeEntry(
        from classification: SpellingInputClassification,
        intent: FingerspellNameIntent,
        isPinned: Bool = false
    ) -> SavedFingerspellEntry? {
        guard let letterWordIds = classification.letterWordIds else { return nil }
        let spellingText: String
        switch classification {
        case .personalName(_, let text, _),
             .properNoun(_, let text, _),
             .unknown(_, let text, _):
            spellingText = text
        default:
            return nil
        }
        return SavedFingerspellEntry(
            id: UUID().uuidString,
            displayText: classification.displayText,
            spellingText: spellingText,
            letterWordIds: letterWordIds,
            intent: intent,
            isPinned: isPinned,
            createdAt: Date().timeIntervalSince1970,
            practiceCount: 0
        )
    }

    private static func curriculumWordId(for normalized: String, store: ASLDataStore) -> String? {
        let lowered = normalized.lowercased()
        if let alias = aliasToWordId[lowered] {
            if store.hasPlayableVideo(for: alias) { return alias }
        }
        if let wordId = store.wordId(matchingNormalizedText: lowered),
           store.hasPlayableVideo(for: wordId) {
            return wordId
        }
        return nil
    }

    private static func formatDisplayName(_ text: String) -> String {
        text
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { part in
                let s = String(part)
                guard let first = s.first else { return s }
                return String(first).uppercased() + s.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

extension ASLDataStore {
    func wordId(matchingNormalizedText normalized: String) -> String? {
        let blocked = CurriculumAwareSpellingResolver.blockedLexicalWordIds

        for (wordId, word) in wordsById {
            guard !blocked.contains(wordId) else { continue }
            if word.normalizedText == normalized { return wordId }
        }

        if FilmedSignCatalog.isFilmed(wordId: normalized),
           !blocked.contains(normalized),
           hasPlayableVideo(for: normalized) {
            return normalized
        }
        return nil
    }
}
