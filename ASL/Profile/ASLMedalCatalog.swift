//
//  ASLMedalCatalog.swift
//  ASL
//

import Foundation

enum MedalCategory: String, CaseIterable, Identifiable {
    case learningPath
    case streak
    case stars
    case signsLearned
    case mastery
    case practice

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .learningPath: return "Learning Path"
        case .streak: return "For Day Streak"
        case .stars: return "Star Medals"
        case .signsLearned: return "Signs Learned"
        case .mastery: return "Mastery Medals"
        case .practice: return "Practice Medals"
        }
    }
}

enum MedalCriterion: Equatable, Hashable {
    case unitComplete(unitId: String)
    case unitsComplete(unitIds: [String])
    case dailyStreakBest(atLeast: Int)
    case totalStars(atLeast: Int)
    case signsLearned(atLeast: Int)
    case inLessonStreakBest(atLeast: Int)
    case practiceSessions(mode: PracticeMode?, atLeast: Int)
    case practiceModesCompleted(atLeast: Int)
}

struct ASLMedalDefinition: Identifiable, Hashable {
    let id: String
    let category: MedalCategory
    let phaseKey: String?
    let phaseTitle: String?
    let title: String
    let subtitle: String
    let description: String
    let symbolName: String
    let paletteIndex: Int?
    let sortOrder: Int
    let criterion: MedalCriterion

    /// Titles that fit under medals on the profile preview row: one word, or “123 Signs”.
    var fitsCompactProfileLabel: Bool {
        if category == .signsLearned {
            return title.range(of: #"^\d+\s+Signs$"#, options: .regularExpression) != nil
        }
        return !title.contains(where: \.isWhitespace)
    }
}

struct MedalSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let category: MedalCategory
    let phaseKey: String?
    let items: [ProfileMedalItem]

    var earnedCount: Int { items.filter(\.isUnlocked).count }
    var totalCount: Int { items.count }
}

enum ASLMedalCatalog {
    private struct PathMedalSpec {
        let id: String
        let phaseKey: String
        let phaseTitle: String
        let title: String
        let subtitle: String
        let description: String
        let symbolName: String
        let paletteIndex: Int
        let sortOrder: Int
        let unitIds: [String]
    }

    /// Medal-only UI phases (not curriculum phaseKey). 24 medals across 6 sections.
    private static let pathMedalSpecs: [PathMedalSpec] = [
        // Phase 1 — First Conversations (6)
        PathMedalSpec(
            id: "group:greetings-quick", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "Hello & Reply", subtitle: "2 units",
            description: "Complete Getting Started and Everyday Replies.",
            symbolName: "hand.wave.fill", paletteIndex: 4, sortOrder: 1,
            unitIds: ["p1-u01", "p1-u02"]
        ),
        PathMedalSpec(
            id: "group:you-introduce", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "You & Me", subtitle: "1 unit",
            description: "Complete You & Me.",
            symbolName: "person.crop.circle.fill", paletteIndex: 1, sortOrder: 2,
            unitIds: ["p1-u03"]
        ),
        PathMedalSpec(
            id: "group:getting-help", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "Getting Help", subtitle: "1 unit",
            description: "Complete Getting Help.",
            symbolName: "lifepreserver.fill", paletteIndex: 9, sortOrder: 3,
            unitIds: ["p1-u73"]
        ),
        PathMedalSpec(
            id: "group:feelings", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "Feelings", subtitle: "1 unit",
            description: "Complete Feelings & Emotions.",
            symbolName: "heart.fill", paletteIndex: 7, sortOrder: 4,
            unitIds: ["p1-u06"]
        ),
        PathMedalSpec(
            id: "group:meet-people", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "Meet People", subtitle: "1 unit",
            description: "Complete Meet People.",
            symbolName: "person.2.fill", paletteIndex: 0, sortOrder: 5,
            unitIds: ["p1-u05"]
        ),
        PathMedalSpec(
            id: "group:deaf-culture", phaseKey: "medal_conversation", phaseTitle: "First Conversations",
            title: "Deaf Culture", subtitle: "1 unit",
            description: "Complete Deaf Culture.",
            symbolName: "hands.sparkles.fill", paletteIndex: 10, sortOrder: 6,
            unitIds: ["p1-u22"]
        ),

        // Phase 2 — Foundations (6)
        PathMedalSpec(
            id: "group:numbers", phaseKey: "medal_foundations", phaseTitle: "Foundations",
            title: "Numbers", subtitle: "1 unit",
            description: "Complete Numbers.",
            symbolName: "number", paletteIndex: 3, sortOrder: 10,
            unitIds: ["p1-u15"]
        ),
        PathMedalSpec(
            id: "group:alphabet", phaseKey: "medal_foundations", phaseTitle: "Foundations",
            title: "Alphabet", subtitle: "1 unit",
            description: "Complete The Alphabet.",
            symbolName: "textformat.abc", paletteIndex: 7, sortOrder: 11,
            unitIds: ["p1-u10"]
        ),
        PathMedalSpec(
            id: "group:everyday-actions", phaseKey: "medal_foundations", phaseTitle: "Foundations",
            title: "Actions & Movement", subtitle: "3 units",
            description: "Complete Everyday Actions, On the Move, and Getting There.",
            symbolName: "figure.walk", paletteIndex: 5, sortOrder: 12,
            unitIds: ["p1-u24", "p1-u23", "p1-u56"]
        ),

        // Phase 3 — Everyday Essentials (6)
        PathMedalSpec(
            id: "group:time-calendar", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Time & Calendar", subtitle: "1 unit",
            description: "Complete Time & Calendar.",
            symbolName: "calendar", paletteIndex: 8, sortOrder: 20,
            unitIds: ["p1-u40"]
        ),
        PathMedalSpec(
            id: "group:family-people", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Family & People", subtitle: "1 unit",
            description: "Complete Family & People.",
            symbolName: "figure.2.and.child.holdinghands", paletteIndex: 0, sortOrder: 21,
            unitIds: ["p1-u18"]
        ),
        PathMedalSpec(
            id: "group:friends-holidays", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Friends & Holidays", subtitle: "1 unit",
            description: "Complete Friends & Holidays.",
            symbolName: "gift.fill", paletteIndex: 6, sortOrder: 22,
            unitIds: ["p1-u49"]
        ),
        PathMedalSpec(
            id: "group:home-furniture", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Home & Furniture", subtitle: "2 units",
            description: "Complete My Home and Furniture.",
            symbolName: "house.fill", paletteIndex: 5, sortOrder: 23,
            unitIds: ["p1-u30", "p1-u31"]
        ),
        PathMedalSpec(
            id: "group:essentials-trio", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Money, School & Town", subtitle: "3 units",
            description: "Complete Money & Counting, School & Classroom, and Health & Town.",
            symbolName: "dollarsign.circle.fill", paletteIndex: 3, sortOrder: 24,
            unitIds: ["p1-u17", "p1-u57", "p1-u45"]
        ),
        PathMedalSpec(
            id: "group:describe-basics", phaseKey: "medal_everyday", phaseTitle: "Everyday Essentials",
            title: "Home, Colors & Size", subtitle: "3 units",
            description: "Complete At Home, Colors, and Size & Amount.",
            symbolName: "paintpalette.fill", paletteIndex: 4, sortOrder: 25,
            unitIds: ["p1-u32", "p1-u27", "p1-u29"]
        ),

        // Phase 4 — Food & Wellbeing (3)
        PathMedalSpec(
            id: "group:mind-body", phaseKey: "medal_wellbeing", phaseTitle: "Food & Wellbeing",
            title: "Mind & Body", subtitle: "2 units",
            description: "Complete Connect Ideas and Body & Wellness.",
            symbolName: "figure.arms.open", paletteIndex: 1, sortOrder: 31,
            unitIds: ["p1-u08", "p1-u42"]
        ),
        PathMedalSpec(
            id: "group:food", phaseKey: "medal_wellbeing", phaseTitle: "Food & Wellbeing",
            title: "Food", subtitle: "2 units",
            description: "Complete Fruits & Veggies and Food & Drinks.",
            symbolName: "fork.knife", paletteIndex: 5, sortOrder: 32,
            unitIds: ["p1-u35", "p1-u37"]
        ),
        PathMedalSpec(
            id: "group:clothes-accessories", phaseKey: "medal_wellbeing", phaseTitle: "Food & Wellbeing",
            title: "Clothes & Accessories", subtitle: "1 unit",
            description: "Complete Clothes & Accessories.",
            symbolName: "tshirt.fill", paletteIndex: 2, sortOrder: 33,
            unitIds: ["p1-u50"]
        ),

        // Phase 5 — Modern Life (3)
        PathMedalSpec(
            id: "group:work-life", phaseKey: "medal_modern_life", phaseTitle: "Modern Life",
            title: "Work Life", subtitle: "1 unit",
            description: "Complete Work Life.",
            symbolName: "briefcase.fill", paletteIndex: 3, sortOrder: 40,
            unitIds: ["p1-u59"]
        ),
        PathMedalSpec(
            id: "group:devices-countries", phaseKey: "medal_modern_life", phaseTitle: "Modern Life",
            title: "Devices & Countries", subtitle: "2 units",
            description: "Complete Devices & Apps and Countries.",
            symbolName: "desktopcomputer", paletteIndex: 8, sortOrder: 41,
            unitIds: ["p1-u69", "p1-u68"]
        ),
        PathMedalSpec(
            id: "group:everyday-sayings", phaseKey: "medal_modern_life", phaseTitle: "Modern Life",
            title: "Everyday Sayings", subtitle: "1 unit",
            description: "Complete Everyday Sayings.",
            symbolName: "lightbulb.fill", paletteIndex: 6, sortOrder: 42,
            unitIds: ["p1-u71"]
        ),

        // Phase 6 — Explore (3)
        PathMedalSpec(
            id: "group:animals", phaseKey: "medal_explore", phaseTitle: "Explore",
            title: "Animals", subtitle: "1 unit",
            description: "Complete Animals.",
            symbolName: "pawprint.fill", paletteIndex: 10, sortOrder: 50,
            unitIds: ["p1-u60"]
        ),
        PathMedalSpec(
            id: "group:weather-nature", phaseKey: "medal_explore", phaseTitle: "Explore",
            title: "Weather & Nature", subtitle: "2 units",
            description: "Complete Weather and Nature & Seasons.",
            symbolName: "leaf.fill", paletteIndex: 7, sortOrder: 51,
            unitIds: ["p1-u63", "p1-u62"]
        ),
        PathMedalSpec(
            id: "group:sports-music", phaseKey: "medal_explore", phaseTitle: "Explore",
            title: "Sports & Music", subtitle: "2 units",
            description: "Complete Sports and Music & Art.",
            symbolName: "sportscourt.fill", paletteIndex: 2, sortOrder: 52,
            unitIds: ["p1-u65", "p1-u66"]
        ),
    ]

    /// Bump when medal IDs or groupings change; triggers silent backfill without celebrations.
    static let medalCatalogVersion = 7

    static var phaseOrder: [(key: String, title: String)] {
        var seen = Set<String>()
        return pathMedalSpecs.compactMap { spec in
            guard seen.insert(spec.phaseKey).inserted else { return nil }
            return (spec.phaseKey, spec.phaseTitle)
        }
    }

    /// Keeps only enough items to fill complete 3-column grid rows.
    static func gridAligned<T>(_ items: [T]) -> [T] {
        let keep = items.count - (items.count % 3)
        guard keep > 0 else { return [] }
        return Array(items.prefix(keep))
    }

    #if DEBUG
    private static func validatePathMedalSpecs() {
        var phaseCounts: [String: Int] = [:]
        var phaseSymbols: [String: Set<String>] = [:]

        for spec in pathMedalSpecs {
            phaseCounts[spec.phaseKey, default: 0] += 1
            phaseSymbols[spec.phaseKey, default: []].insert(spec.symbolName)
        }

        let allUnits = pathMedalSpecs.flatMap(\.unitIds)
        let uniqueUnits = Set(allUnits)
        precondition(allUnits.count == uniqueUnits.count, "Duplicate unit IDs in pathMedalSpecs")
        precondition(uniqueUnits.count == 37, "Expected 37 module units, got \(uniqueUnits.count)")

        for (phase, count) in phaseCounts {
            precondition(count >= 3 && count % 3 == 0, "Phase \(phase) has \(count) medals (need multiple of 3, min 3)")
            precondition(phaseSymbols[phase]?.count == count, "Phase \(phase) has duplicate medal icons")
        }
    }
    #endif

    static func allDefinitions(from store: ASLDataStore) -> [ASLMedalDefinition] {
        pathMedals(from: store) + achievementMedals
    }

    static func pathMedals(from store: ASLDataStore) -> [ASLMedalDefinition] {
        #if DEBUG
        validatePathMedalSpecs()
        #endif

        guard let pathId = store.paths.first?.id,
              let units = store.unitsByPathId[pathId]
        else { return [] }

        let unitsById = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })

        return pathMedalSpecs.compactMap { spec in
            let knownUnitIds = spec.unitIds.filter { unitId in
                guard let unit = unitsById[unitId] else { return false }
                return !unit.isReview
            }
            guard !knownUnitIds.isEmpty else { return nil }

            let paletteIndex = UnitPalette.paletteIndex(forUnitIds: knownUnitIds, in: units)

            return ASLMedalDefinition(
                id: spec.id,
                category: .learningPath,
                phaseKey: spec.phaseKey,
                phaseTitle: spec.phaseTitle,
                title: spec.title,
                subtitle: spec.subtitle,
                description: spec.description,
                symbolName: spec.symbolName,
                paletteIndex: paletteIndex,
                sortOrder: spec.sortOrder,
                criterion: .unitsComplete(unitIds: knownUnitIds)
            )
        }
    }

    static let achievementMedals: [ASLMedalDefinition] = {
        var medals: [ASLMedalDefinition] = []
        var order = 1_000

        let streakSymbols = ["flame.fill", "flame.circle.fill", "sun.max.fill", "bolt.heart.fill", "calendar.badge.clock", "trophy.fill"]
        let starSymbols = ["star.fill", "star.circle.fill", "star.leadinghalf.filled", "sparkles", "crown.fill", "medal.fill"]
        let signPalettes = [0, 1, 2, 3, 4, 5]
        let signSymbols = ["hands.clap.fill", "hand.wave.fill", "hand.point.up.left.fill", "hand.raised.fill", "hand.thumbsup.fill", "person.2.fill"]
        let masteryPalettes = [0, 1, 2, 3, 4, 5]
        let masterySymbols = ["bolt.fill", "bolt.circle.fill", "target", "scope", "checkmark.seal.fill", "rosette"]
        /// Slots into `UnitPalette.practiceModePalettes` — green, orange, blue like Practice tab.
        let practicePalettes = [0, 1, 2, 3, 0, 1, 2]
        let practiceSymbols = [
            "figure.run",
            "brain.head.profile",
            "link.circle.fill",
            "textformat.123",
            "square.grid.3x3.fill",
            "repeat.circle.fill",
            "chart.line.uptrend.xyaxis",
        ]

        let streakTiers: [(Int, String, String)] = [
            (3, "Getting Warm", "Reach a 3-day activity streak"),
            (7, "Week Warrior", "Reach a 7-day activity streak"),
            (14, "Two-Week Flame", "Reach a 14-day activity streak"),
            (30, "Monthly Momentum", "Reach a 30-day activity streak"),
            (60, "Dedicated Learner", "Reach a 60-day activity streak"),
            (100, "Century Streak", "Reach a 100-day activity streak"),
        ]
        for (index, (threshold, title, hint)) in streakTiers.enumerated() {
            medals.append(ASLMedalDefinition(
                id: "streak:\(threshold)",
                category: .streak,
                phaseKey: nil,
                phaseTitle: nil,
                title: title,
                subtitle: "\(threshold)-day streak",
                description: hint,
                symbolName: streakSymbols[index],
                paletteIndex: nil,
                sortOrder: order,
                criterion: .dailyStreakBest(atLeast: threshold)
            ))
            order += 1
        }

        let starTiers = [50, 100, 250, 500, 1000, 2500]
        for (index, threshold) in starTiers.enumerated() {
            medals.append(ASLMedalDefinition(
                id: "stars:\(threshold)",
                category: .stars,
                phaseKey: nil,
                phaseTitle: nil,
                title: "\(threshold) Stars",
                subtitle: "Collect \(threshold) stars",
                description: "Earn \(threshold) total stars across lessons, practice, and the dictionary.",
                symbolName: starSymbols[index],
                paletteIndex: nil,
                sortOrder: order,
                criterion: .totalStars(atLeast: threshold)
            ))
            order += 1
        }

        let signTiers = [10, 25, 50, 100, 200, 500]
        for (index, threshold) in signTiers.enumerated() {
            medals.append(ASLMedalDefinition(
                id: "signs:\(threshold)",
                category: .signsLearned,
                phaseKey: nil,
                phaseTitle: nil,
                title: "\(threshold) Signs",
                subtitle: "Learn \(threshold) signs",
                description: "Learn \(threshold) unique signs on your path and in the dictionary.",
                symbolName: signSymbols[index],
                paletteIndex: signPalettes[index],
                sortOrder: order,
                criterion: .signsLearned(atLeast: threshold)
            ))
            order += 1
        }

        let masteryTiers: [(Int, String)] = [
            (4, "Hot Streak"),
            (8, "On Fire"),
            (12, "Unstoppable"),
            (20, "Precision Pro"),
            (30, "Perfect Run"),
            (40, "Flawless Focus"),
        ]
        for (index, (threshold, title)) in masteryTiers.enumerated() {
            medals.append(ASLMedalDefinition(
                id: "mastery:\(threshold)",
                category: .mastery,
                phaseKey: nil,
                phaseTitle: nil,
                title: title,
                subtitle: "\(threshold) in a row",
                description: "Get \(threshold) correct answers in a row during a lesson.",
                symbolName: masterySymbols[index],
                paletteIndex: masteryPalettes[index],
                sortOrder: order,
                criterion: .inLessonStreakBest(atLeast: threshold)
            ))
            order += 1
        }

        let practiceFirst: [(PracticeMode, String, String)] = [
            (.quiz, "Quiz Whiz", "Complete a Quiz session"),
            (.flashcards, "Flashcard Pro", "Complete a Flashcards session"),
            (.vocabularyMatch, "Match Master", "Complete a Vocabulary Match session"),
            (.spellYourName, "Name Speller", "Complete a Spell Your Name session"),
        ]
        for (index, (mode, title, description)) in practiceFirst.enumerated() {
            medals.append(ASLMedalDefinition(
                id: "practice:first:\(mode.rawValue)",
                category: .practice,
                phaseKey: nil,
                phaseTitle: nil,
                title: title,
                subtitle: mode.title,
                description: description,
                symbolName: practiceSymbols[index],
                paletteIndex: practicePalettes[index],
                sortOrder: order,
                criterion: .practiceSessions(mode: mode, atLeast: 1)
            ))
            order += 1
        }

        medals.append(ASLMedalDefinition(
            id: "practice:modes:3",
            category: .practice,
            phaseKey: nil,
            phaseTitle: nil,
            title: "Triple Threat",
            subtitle: "All practice modes",
            description: "Complete at least one session in every practice mode.",
            symbolName: practiceSymbols[4],
            paletteIndex: practicePalettes[4],
            sortOrder: order,
            criterion: .practiceModesCompleted(atLeast: 4)
        ))
        order += 1

        for (index, threshold) in [10, 50].enumerated() {
            let title = threshold == 10 ? "Practice Regular" : "Practice Pro"
            medals.append(ASLMedalDefinition(
                id: "practice:sessions:\(threshold)",
                category: .practice,
                phaseKey: nil,
                phaseTitle: nil,
                title: title,
                subtitle: "\(threshold) sessions",
                description: "Complete \(threshold) practice sessions across all modes.",
                symbolName: practiceSymbols[index + 5],
                paletteIndex: practicePalettes[index + 5],
                sortOrder: order,
                criterion: .practiceSessions(mode: nil, atLeast: threshold)
            ))
            order += 1
        }

        return medals
    }()
}
