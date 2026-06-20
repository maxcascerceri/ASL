//
//  FavoriteSignsStore.swift
//  ASL
//

import Foundation

enum FavoriteSignsStore {
    private static let storageKey = "asl.favoriteSigns.v1"

    static func wordIds() -> Set<String> {
        guard
            let data = UserDefaults.standard.string(forKey: storageKey)?.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(decoded)
    }

    static func contains(_ wordId: String) -> Bool {
        wordIds().contains(wordId)
    }

    static var count: Int { wordIds().count }
}
