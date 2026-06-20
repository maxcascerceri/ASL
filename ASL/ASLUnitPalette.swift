//
//  ASLUnitPalette.swift
//  ASL
//

import SwiftUI

struct UnitPalette {
    let color: Color
    let shadow: Color
    let symbol: String

    /// Six colors cycled across home units (Signs dictionary uses Brand dictionary pastels).
    /// Order matches the first six dictionary categories: Getting Started, Everyday Replies,
    /// Pronouns, Ask & Answer, People Words, and Check-ins.
    static let palettes: [UnitPalette] = [
        UnitPalette(
            color: Brand.primary,
            shadow: Brand.primaryShadow,
            symbol: "sparkles"
        ),
        UnitPalette(
            color: Color(red: 0.39, green: 0.77, blue: 0.47),
            shadow: Color(red: 0.25, green: 0.59, blue: 0.34),
            symbol: "cup.and.saucer.fill"
        ),
        UnitPalette(
            color: Color(red: 0.57, green: 0.49, blue: 0.88),
            shadow: Color(red: 0.42, green: 0.37, blue: 0.70),
            symbol: "heart.circle.fill"
        ),
        UnitPalette(
            color: Color(red: 0.94, green: 0.57, blue: 0.66),
            shadow: Color(red: 0.77, green: 0.39, blue: 0.51),
            symbol: "heart.fill"
        ),
        UnitPalette(
            color: Color(red: 0.96, green: 0.61, blue: 0.11),
            shadow: Color(red: 0.79, green: 0.46, blue: 0.07),
            symbol: "flame.fill"
        ),
        UnitPalette(
            color: Color(red: 0.24, green: 0.69, blue: 0.89),
            shadow: Color(red: 0.15, green: 0.54, blue: 0.73),
            symbol: "questionmark.circle.fill"
        )
    ]

    static func palette(for index: Int) -> UnitPalette {
        palettes[index % palettes.count]
    }

    /// Matches home path row coloring: `UnitPalette.palette(for: unitIndex)`.
    static func paletteIndex(forUnitAt unitIndex: Int) -> Int {
        ((unitIndex % palettes.count) + palettes.count) % palettes.count
    }

    /// Earliest path position among `unitIds`, using the same unit order as the home screen.
    static func paletteIndex(forUnitIds unitIds: [String], in units: [ASLUnit]) -> Int {
        let index = units.enumerated().first(where: { unitIds.contains($0.element.id) })?.offset ?? 0
        return paletteIndex(forUnitAt: index)
    }

    /// Gold Total Stars profile card — outside the six-color unit cycle.
    static let profileStars = UnitPalette(
        color: Color(red: 0.97, green: 0.76, blue: 0.23),
        shadow: Color(red: 0.79, green: 0.57, blue: 0.06),
        symbol: "star.fill"
    )

    /// Orange Daily Streak profile card — warmer than unit index 4.
    static let profileStreak = UnitPalette(
        color: Color(red: 0.97, green: 0.59, blue: 0.12),
        shadow: Color(red: 0.80, green: 0.43, blue: 0.06),
        symbol: "flame.fill"
    )

    /// Sign Sprint, Memory Challenge, Alphabet Matching — same order as Practice tab cards.
    static let practiceModePalettes: [UnitPalette] = [
        palette(for: 1),
        palette(for: 4),
        palette(for: 0),
    ]

    /// Medal fill colors aligned with home units, Signs categories, Practice modes, and profile stat cards.
    static func medalPalette(for definition: ASLMedalDefinition) -> UnitPalette {
        switch definition.category {
        case .streak:
            return profileStreak
        case .stars:
            return profileStars
        case .signsLearned:
            return palette(for: definition.paletteIndex ?? 0)
        case .practice:
            let slot = definition.paletteIndex ?? 0
            return practiceModePalettes[slot % practiceModePalettes.count]
        case .learningPath, .mastery:
            let index = definition.paletteIndex ?? definition.sortOrder
            return palette(for: index)
        }
    }
}
