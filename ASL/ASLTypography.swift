//
//  ASLTypography.swift
//  ASL
//
//  Semantic text roles — Instrument Serif for display, DM Sans for UI and reading.
//

import SwiftUI

// MARK: - Custom fonts

/// PostScript names for bundled fonts in `ASL/Fonts/`.
enum ASLFontName {
    static let displayRegular = "InstrumentSerif-Regular"
    static let displayItalic = "InstrumentSerif-Italic"

    static let uiRegular = "DMSans-Regular"
    static let uiMedium = "DMSans-Medium"
    static let uiSemiBold = "DMSans-SemiBold"
    static let uiBold = "DMSans-Bold"

    static func ui(for weight: Font.Weight) -> String {
        switch weight {
        case .medium:
            return uiMedium
        case .semibold:
            return uiSemiBold
        case .bold, .heavy, .black:
            return uiBold
        default:
            return uiRegular
        }
    }
}

// MARK: - Design

/// Font family per role — display (serif) for titles, ui (sans) for everything else.
enum ASLFontDesign {
    case display
    case ui

    /// Legacy alias used by lesson layout call sites.
    static let reading: ASLFontDesign = .ui
}

// MARK: - Roles

/// Semantic text roles used across the app.
enum ASLTextRole {
    /// Tab and screen headers — "Practice", "Signs", "Getting Started".
    case pageTitle
    /// Practice, Signs, and Profile curved-panel headers — bolder sans at larger scale.
    case tabScreenTitle
    /// Supporting line under a page title.
    case subtitle
    /// Raised card and list row headings.
    case cardTitle
    /// Secondary copy on cards.
    case cardDescription
    /// Primary CTAs — pill buttons, avoid all-caps at call sites.
    case button
    /// Bottom tab labels.
    case tabBar
    /// Stat numbers paired with icons — streak, stars, profile metrics.
    case progressStat
    /// Small stat / metadata labels under numbers.
    case progressLabel
    /// Centered section headers with horizontal rules.
    case sectionTitle
    /// Celebration and milestone headlines.
    case celebrationHeadline
    /// Large star counts on celebration screens.
    case celebrationStat
}

/// Background the text sits on — drives default foreground colors.
enum ASLTextSurface {
    /// White type on a colored raised card.
    case colored
    /// Charcoal / gray on white or brand chrome.
    case light
}

/// Size step within each role's documented range.
enum ASLTextVariant {
    case compact
    case standard
    case prominent
}

// MARK: - Metrics

enum ASLTextMetrics {
    static func size(for role: ASLTextRole, variant: ASLTextVariant) -> CGFloat {
        switch (role, variant) {
        case (.pageTitle, .compact): return 28
        case (.pageTitle, .standard): return 32
        case (.pageTitle, .prominent): return 36

        case (.tabScreenTitle, .compact): return 34
        case (.tabScreenTitle, .standard): return 36
        case (.tabScreenTitle, .prominent): return 38

        case (.subtitle, .compact): return 15
        case (.subtitle, .standard): return 16
        case (.subtitle, .prominent): return 17

        case (.cardTitle, .compact): return 16
        case (.cardTitle, .standard): return 17
        case (.cardTitle, .prominent): return 18

        case (.cardDescription, .compact): return 14
        case (.cardDescription, .standard): return 15
        case (.cardDescription, .prominent): return 16

        case (.button, .compact): return 16
        case (.button, .standard): return 17
        case (.button, .prominent): return 18

        case (.tabBar, .compact): return 12
        case (.tabBar, .standard): return 13
        case (.tabBar, .prominent): return 14

        case (.progressStat, .compact): return 22
        case (.progressStat, .standard): return 24
        case (.progressStat, .prominent): return 28

        case (.progressLabel, .compact): return 11
        case (.progressLabel, .standard): return 12
        case (.progressLabel, .prominent): return 13

        case (.sectionTitle, .compact): return 12
        case (.sectionTitle, .standard): return 12
        case (.sectionTitle, .prominent): return 13

        case (.celebrationHeadline, .compact): return 24
        case (.celebrationHeadline, .standard): return 26
        case (.celebrationHeadline, .prominent): return 28

        case (.celebrationStat, .compact): return 40
        case (.celebrationStat, .standard): return 44
        case (.celebrationStat, .prominent): return 48
        }
    }

    static func weight(for role: ASLTextRole) -> Font.Weight {
        switch role {
        case .pageTitle, .celebrationHeadline:
            return .regular
        case .tabScreenTitle:
            return .bold
        case .progressStat, .celebrationStat:
            return .semibold
        case .subtitle, .cardDescription, .progressLabel:
            return .regular
        case .cardTitle, .sectionTitle:
            return .medium
        case .tabBar, .button:
            return .semibold
        }
    }

    static func design(for role: ASLTextRole) -> ASLFontDesign {
        switch role {
        case .pageTitle, .celebrationHeadline:
            return .display
        default:
            return .ui
        }
    }

    static func tracking(for role: ASLTextRole) -> CGFloat {
        switch role {
        case .pageTitle:
            return -0.3
        case .tabScreenTitle:
            return -0.4
        case .sectionTitle:
            return 0.8
        case .progressLabel, .tabBar:
            return 0.3
        default:
            return 0
        }
    }

    static func lineSpacing(for role: ASLTextRole) -> CGFloat {
        switch role {
        case .subtitle:
            return 4
        case .cardDescription:
            return 3
        default:
            return 0
        }
    }

    static func usesMonospacedDigits(for role: ASLTextRole) -> Bool {
        switch role {
        case .progressStat, .celebrationStat:
            return true
        default:
            return false
        }
    }

    static func foregroundStyle(for role: ASLTextRole, surface: ASLTextSurface) -> Color {
        switch (role, surface) {
        case (.pageTitle, _), (.tabScreenTitle, _), (.progressStat, .light), (.cardTitle, .light),
             (.celebrationHeadline, _), (.celebrationStat, _):
            return Brand.textPrimary
        case (.subtitle, _), (.cardDescription, .light), (.progressLabel, .light), (.sectionTitle, _):
            return Brand.secondaryLabel
        case (.cardTitle, .colored), (.progressStat, .colored):
            return .white
        case (.cardDescription, .colored), (.progressLabel, .colored):
            return .white.opacity(0.78)
        case (.button, _), (.tabBar, _):
            return Brand.textPrimary
        }
    }
}

// MARK: - Font

extension Font {
    /// Bundled custom font at an explicit size — prefer semantic roles when possible.
    static func asl(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: ASLFontDesign = .ui
    ) -> Font {
        switch design {
        case .display:
            return .custom(ASLFontName.displayRegular, size: size)
        case .ui:
            return .custom(ASLFontName.ui(for: weight), size: size)
        }
    }

    /// DM Sans for body and reading copy (legacy name kept for lesson call sites).
    static func aslReading(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .asl(size, weight: weight, design: .ui)
    }

    /// Semantic font for a text role and size variant.
    static func asl(_ role: ASLTextRole, variant: ASLTextVariant = .standard) -> Font {
        let size = ASLTextMetrics.size(for: role, variant: variant)
        let weight = ASLTextMetrics.weight(for: role)
        return asl(size, weight: weight, design: ASLTextMetrics.design(for: role))
    }
}

// MARK: - Text styling

extension Text {
    /// Applies role font, default color, and role-specific tracking / line spacing.
    @ViewBuilder
    func aslStyle(
        _ role: ASLTextRole,
        surface: ASLTextSurface = .light,
        variant: ASLTextVariant = .standard,
        color: Color? = nil
    ) -> some View {
        let styled = self
            .font(.asl(role, variant: variant))
            .foregroundStyle(color ?? ASLTextMetrics.foregroundStyle(for: role, surface: surface))
            .tracking(ASLTextMetrics.tracking(for: role))
            .lineSpacing(ASLTextMetrics.lineSpacing(for: role))

        if ASLTextMetrics.usesMonospacedDigits(for: role) {
            styled.monospacedDigit()
        } else {
            styled
        }
    }
}

extension View {
    /// Font only — use when foreground color is applied separately (tabs, toggles).
    @ViewBuilder
    func aslFont(_ role: ASLTextRole, variant: ASLTextVariant = .standard) -> some View {
        let roleFont = Font.asl(role, variant: variant)
        if ASLTextMetrics.usesMonospacedDigits(for: role) {
            font(roleFont).monospacedDigit()
        } else {
            font(roleFont)
        }
    }
}
