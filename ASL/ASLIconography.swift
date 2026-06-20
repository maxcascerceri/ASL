//
//  ASLIconography.swift
//  ASL
//
//  Cohesive SF Symbol styling — weights, density, rendering, and motion.
//

import SwiftUI
import UIKit

// MARK: - Roles

/// Semantic icon roles used across the app.
enum ASLIconRole {
    /// Home stats row — flame, star, signs learned.
    case metric
    /// Lesson stone glyph on a colored disc.
    case lessonStone
    /// Unit header badge on white coin.
    case unitBadge
    /// Raised toolbar controls — settings, scroll-to-top.
    case toolbar
    /// Inline navigation affordances — back, close, chevrons.
    case navigation
    /// Small utility glyphs — search clear, list chevrons.
    case utility
    /// Playful accents — sparkles, continue bubble.
    case decorative
    /// Large hero icons on category cards.
    case categoryHero
    /// Signs dictionary browse grid category tiles.
    case dictionaryCategory
    /// Icons inside cream circular badges — profile, practice modes.
    case badgeDisc
    /// Empty states and sheet actions.
    case feature
}

// MARK: - Metrics

enum ASLIconMetrics {
    static let metric: CGFloat = 21
    static let lessonStone: CGFloat = 26
    static let unitBadge: CGFloat = 20
    static let toolbar: CGFloat = 18
    static let navigation: CGFloat = 17
    static let utility: CGFloat = 14
    static let decorative: CGFloat = 16
    static let categoryHero: CGFloat = 34
    static let dictionaryCategory: CGFloat = 44
    static let badgeDisc: CGFloat = 22
    static let feature: CGFloat = 30

    static let tab: CGFloat = 42
    static let tabSelectedScale: CGFloat = 1.045
    static let tabPressedScale: CGFloat = 0.94

    static func size(for role: ASLIconRole) -> CGFloat {
        switch role {
        case .metric: return metric
        case .lessonStone: return lessonStone
        case .unitBadge: return unitBadge
        case .toolbar: return toolbar
        case .navigation: return navigation
        case .utility: return utility
        case .decorative: return decorative
        case .categoryHero: return categoryHero
        case .dictionaryCategory: return dictionaryCategory
        case .badgeDisc: return badgeDisc
        case .feature: return feature
        }
    }

    static func weight(for role: ASLIconRole) -> Font.Weight {
        switch role {
        case .utility, .navigation, .toolbar, .unitBadge:
            return .bold
        default:
            return .semibold
        }
    }

    static func renderingMode(for role: ASLIconRole) -> SymbolRenderingMode {
        switch role {
        case .lessonStone, .navigation, .utility, .toolbar, .unitBadge:
            return .monochrome
        default:
            return .hierarchical
        }
    }

    /// Optical compensation — heavy filled symbols read larger at the same point size.
    static func opticalScale(for role: ASLIconRole) -> CGFloat {
        switch role {
        case .lessonStone: return 0.96
        case .categoryHero, .dictionaryCategory: return 0.94
        case .badgeDisc: return 0.97
        default: return 1
        }
    }

    static func usesEmboss(for role: ASLIconRole) -> Bool {
        switch role {
        case .badgeDisc, .categoryHero, .dictionaryCategory, .decorative:
            return true
        default:
            return false
        }
    }

    static func deemphasizedOpacity(for role: ASLIconRole) -> Double {
        switch role {
        case .utility: return 0.72
        case .navigation: return 0.78
        default: return 1
        }
    }
}

// MARK: - Motion

enum ASLIconMotion {
    static let tap = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let selection = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let valueChange = Animation.spring(response: 0.45, dampingFraction: 0.75)
}

// MARK: - ASL icon view

struct ASLIcon: View {
    enum Source {
        case symbol(String)
        case symbolVariable(String, value: Double)
        case asset(String)
    }

    let source: Source
    var role: ASLIconRole
    var tint: Color
    var isEmphasis: Bool = true
    var bounceTrigger: Int = 0
    var assetSize: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch source {
            case .symbol(let name):
                Image(systemName: name)
            case .symbolVariable(let name, let value):
                Image(systemName: name, variableValue: value)
            case .asset(let name):
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: assetSize ?? ASLIconMetrics.size(for: role),
                           height: assetSize ?? ASLIconMetrics.size(for: role))
            }
        }
        .modifier(ASLIconStyleModifier(
            role: role,
            tint: tint,
            isEmphasis: isEmphasis,
            bounceTrigger: bounceTrigger,
            reduceMotion: reduceMotion,
            symbolSize: {
                if case .asset = source { return nil }
                return assetSize
            }(),
            appliesFont: {
                if case .asset = source { return false }
                return true
            }()
        ))
    }
}

/// Custom PNG tab bar icons — keeps branded artwork, unified selection motion.
struct ASLTabIcon: View {
    let assetName: String
    let isSelected: Bool
    var isPressed: Bool = false

    var body: some View {
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: ASLIconMetrics.tab, height: ASLIconMetrics.tab)
            .scaleEffect(scale)
            .animation(ASLIconMotion.selection, value: isSelected)
            .animation(ASLIconMotion.tap, value: isPressed)
    }

    private var scale: CGFloat {
        if isPressed { return ASLIconMetrics.tabPressedScale }
        if isSelected { return ASLIconMetrics.tabSelectedScale }
        return 1
    }
}

// MARK: - Modifiers

private struct ASLIconStyleModifier: ViewModifier {
    let role: ASLIconRole
    let tint: Color
    let isEmphasis: Bool
    let bounceTrigger: Int
    let reduceMotion: Bool
    var symbolSize: CGFloat? = nil
    let appliesFont: Bool

    func body(content: Content) -> some View {
        content
            .modifier(OptionalFontModifier(
                applies: appliesFont,
                size: symbolSize ?? ASLIconMetrics.size(for: role),
                weight: ASLIconMetrics.weight(for: role)
            ))
            .symbolRenderingMode(ASLIconMetrics.renderingMode(for: role))
            .foregroundStyle(tint)
            .opacity(isEmphasis ? 1 : ASLIconMetrics.deemphasizedOpacity(for: role))
            .scaleEffect(ASLIconMetrics.opticalScale(for: role))
            .modifier(ASLIconEmbossModifier(enabled: ASLIconMetrics.usesEmboss(for: role)))
            .symbolEffect(.bounce, value: bounceTrigger)
    }
}

private struct OptionalFontModifier: ViewModifier {
    let applies: Bool
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        if applies {
            content.font(.asl(size, weight: weight))
        } else {
            content
        }
    }
}

struct ASLIconEmbossModifier: ViewModifier {
    var enabled: Bool = true

    func body(content: Content) -> some View {
        content.shadow(
            color: enabled ? Color.white.opacity(0.52) : .clear,
            radius: 0,
            x: 0.75,
            y: 0.75
        )
    }
}

struct ASLIconPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(ASLIconMotion.tap, value: isPressed)
    }
}

// MARK: - View helpers

extension View {
    func aslIconEmboss(enabled: Bool = true) -> some View {
        modifier(ASLIconEmbossModifier(enabled: enabled))
    }

    func aslIconPress(isPressed: Bool) -> some View {
        modifier(ASLIconPressModifier(isPressed: isPressed))
    }
}

extension Image {
    func aslIconStyle(
        role: ASLIconRole,
        tint: Color,
        isEmphasis: Bool = true
    ) -> some View {
        self.modifier(ASLIconStyleModifier(
            role: role,
            tint: tint,
            isEmphasis: isEmphasis,
            bounceTrigger: 0,
            reduceMotion: false,
            appliesFont: true
        ))
    }
}

// MARK: - Shared symbols

enum ASLIconSymbol {
    /// First available ASL-related symbol for the current OS.
    static let signsLearned: String = {
        let candidates = [
            "figure.american.sign.language",
            "hands.clap.fill",
            "hand.wave.fill",
        ]
        for name in candidates where UIImage(systemName: name) != nil {
            return name
        }
        return "hand.wave.fill"
    }()
}
