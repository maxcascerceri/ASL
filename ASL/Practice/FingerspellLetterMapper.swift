//
//  FingerspellLetterMapper.swift
//  ASL
//

import Foundation

enum FingerspellLetterMapper {
    private static let charToWordId: [Character: String] = {
        var map: [Character: String] = [:]
        for wordId in PracticeAlphabet.letterWordIds {
            let char = displayCharacter(for: wordId)
            map[char] = wordId
        }
        return map
    }()

    static func displayCharacter(for wordId: String) -> Character {
        if wordId == "letteri" { return "I" }
        guard let first = wordId.first else { return "?" }
        return Character(String(first).uppercased())
    }

    static func wordId(for character: Character) -> String? {
        charToWordId[Character(String(character).uppercased())]
    }

    static func wordIds(for spellingText: String) -> [String]? {
        let letters = normalizedSpellingCharacters(from: spellingText)
        guard !letters.isEmpty else { return nil }
        var ids: [String] = []
        for char in letters {
            guard let wordId = wordId(for: char) else { return nil }
            ids.append(wordId)
        }
        return ids
    }

    static func normalizedSpellingCharacters(from text: String) -> [Character] {
        normalizedSpellingString(from: text).map { $0 }
    }

    /// Strips separators for spelling; keeps display text separate.
    static func normalizedSpellingString(from text: String) -> String {
        let stripped = text
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .uppercased()
            .filter { $0.isLetter }
        return String(stripped)
    }

    static func displayLabel(for wordId: String) -> String {
        String(displayCharacter(for: wordId))
    }

    static func isSupportedSpellingText(_ text: String) -> Bool {
        let normalized = normalizedSpellingString(from: text)
        guard normalized.count >= 2, normalized.count <= 20 else { return false }
        return normalized.allSatisfy { wordId(for: $0) != nil }
    }

    static func validationMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a name to practice." }
        let normalized = normalizedSpellingString(from: trimmed)
        guard normalized.count >= 2 else { return "Use at least 2 letters." }
        guard normalized.count <= 20 else { return "Keep it to 20 letters or fewer." }
        let unsupported = normalizedSpellingCharacters(from: trimmed).filter { wordId(for: $0) == nil }
        if !unsupported.isEmpty {
            return "Use A–Z letters only for now."
        }
        return nil
    }
}
