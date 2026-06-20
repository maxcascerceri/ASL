//
//  SignCategoryCatalog.swift
//  ASL
//

import Foundation

struct SignCategoryEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let wordIds: [String]
}

enum SignCategoryCatalog {
    /// Subset of dictionary categories used for daily practice rotation.
    static let dailyRotation: [SignCategoryEntry] = [
        SignCategoryEntry(id: "greetings", title: "Getting Started", wordIds: ["hello", "bye", "please", "thankyou", "sorry", "welcome", "name", "nice", "meet"]),
        SignCategoryEntry(id: "check-ins", title: "Check-ins", wordIds: ["fine", "good", "great", "bad", "happy", "sad", "tired", "angry", "scared", "excited", "worry"]),
        SignCategoryEntry(id: "family", title: "Family", wordIds: ["mother", "father", "sister", "brother", "baby", "child", "family", "parents", "grandmother", "grandfather", "aunt", "uncle", "cousin", "niece", "nephew", "twins"]),
        SignCategoryEntry(id: "mealtime", title: "Mealtime", wordIds: ["breakfast", "lunch", "dinner", "hungry", "full", "delicious"]),
        SignCategoryEntry(id: "colors", title: "Colors", wordIds: ["red", "blue", "green", "yellow", "orange", "purple", "pink", "brown", "black", "white", "gray", "gold", "silver"]),
        SignCategoryEntry(id: "questions", title: "Ask & Answer", wordIds: ["what", "where", "when", "who", "why", "how", "which"]),
        SignCategoryEntry(id: "home", title: "Home", wordIds: ["home", "house", "kitchen", "bathroom", "bedroom", "livingroom", "basement", "backyard"]),
        SignCategoryEntry(id: "school", title: "School", wordIds: ["school", "class", "student", "teacher", "learn", "study", "read", "write", "math", "science", "history", "art", "book", "pen", "paper"])
    ]

    static func category(withId id: String) -> SignCategoryEntry? {
        dailyRotation.first { $0.id == id }
    }

    static func category(containingWordId wordId: String) -> SignCategoryEntry? {
        dailyRotation.first { $0.wordIds.contains(wordId) }
    }

    static func categoryForDaySeed(_ dayKey: String) -> SignCategoryEntry {
        let hash = dayKey.utf8.reduce(0) { ($0 &+ Int($1)) &* 31 }
        let index = abs(hash) % dailyRotation.count
        return dailyRotation[index]
    }

    /// First Signs, Everyday Replies, and Pronouns — background poster warm-up at launch.
    static let dictionaryLaunchPosterWordIds: [String] = {
        let categories: [[String]] = [
            [
                "hello", "bye", "please", "thankyou", "sorry", "welcome", "name", "congratulations",
                "oops", "nice", "meet", "introduce", "sign", "mynameis", "nicetomeetyou", "howareyou",
                "imfine", "signslow", "yourewelcome", "thankyouverymuch",
            ],
            [
                "yes", "no", "sure", "wow", "really", "alright", "ok", "again", "wait", "nevermind",
                "maybe", "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere",
                "havegoodday", "nicetoseeyou", "cool", "awesome", "funny",
            ],
            [
                "i", "me", "you", "we", "us", "our", "my", "your", "his", "mine", "he", "they",
                "she", "her", "him", "them", "their", "yours", "ours",
            ],
        ]
        var seen = Set<String>()
        var result: [String] = []
        for wordIds in categories {
            for wordId in wordIds where seen.insert(wordId).inserted {
                result.append(wordId)
            }
        }
        return result
    }()
}
