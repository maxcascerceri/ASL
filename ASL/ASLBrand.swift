//
//  ASLBrand.swift
//  ASL
//
//  Mascot-aligned brand shell (blue + cream). Unit lesson colors stay in UnitPalette / LessonPalette.
//

import SwiftUI
import UIKit

enum Brand {
    /// Primary brand blue (#648EF4) — unit 1, tab bar, signs chrome, links.
    static let primary = Color(red: 100 / 255, green: 142 / 255, blue: 244 / 255)
    /// Deeper blue for pressed states and shadows.
    static let primaryShadow = Color(red: 60 / 255, green: 107 / 255, blue: 200 / 255)
    /// Periwinkle wash — chips, halos, header gradients.
    static let soft = Color(red: 0.85, green: 0.90, blue: 0.99)
    /// Warm off-white from the mascot belly.
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.95)
    /// Beak / feet charcoal for outlines when needed.
    static let ink = Color(red: 0.15, green: 0.17, blue: 0.22)

    /// App-wide page background (cream-blue).
    static let canvas = Color(red: 0.97, green: 0.98, blue: 1.00)

    /// Tab bar and elevated chrome.
    static let chrome = Color(red: 0.99, green: 0.99, blue: 1.00)

    /// Home feed background — matches curved panel chrome on Profile and Practice tabs.
    static let homeBackground = chrome

    /// Subtle rules between sections (replaces flat systemGray dividers on brand screens).
    static let divider = Color(red: 0.82, green: 0.88, blue: 0.94)

    /// Muted label on brand chrome.
    static let secondaryLabel = Color(red: 0.38, green: 0.44, blue: 0.52)

    /// Legal copy, hints, and disabled metadata — lighter than secondaryLabel.
    static let tertiaryLabel = Color(red: 0.38, green: 0.44, blue: 0.52).opacity(0.65)

    /// Primary reading text — soft charcoal on light backgrounds (not pure black).
    static let textPrimary = Color(red: 0.22, green: 0.24, blue: 0.29)

    static let textPrimaryUIColor = UIColor(red: 0.22, green: 0.24, blue: 0.29, alpha: 1)

    /// Resolved/disabled tile fill.
    static let neutralFill = Color(red: 0.90, green: 0.90, blue: 0.92)
    /// Tile border and inactive stroke.
    static let neutralBorder = Color(red: 0.82, green: 0.82, blue: 0.84)
    /// Quiet neutral surface for video plates and inline blanks.
    static let neutralSurface = Color(red: 0.95, green: 0.95, blue: 0.97)

    // MARK: - Signs dictionary category pastels

    /// Soft sky blue face for alternating dictionary category cards.
    static let dictionaryBlue = Color(red: 0.82, green: 0.91, blue: 0.98)
    static let dictionaryBlueDepth = Color(red: 0.52, green: 0.68, blue: 0.84)
    static let dictionaryBlueIcon = Color(red: 0.42, green: 0.66, blue: 0.88)

    /// Soft mint face for alternating dictionary category cards.
    static let dictionaryMint = Color(red: 0.84, green: 0.96, blue: 0.91)
    static let dictionaryMintDepth = Color(red: 0.48, green: 0.72, blue: 0.62)
    static let dictionaryMintIcon = Color(red: 0.32, green: 0.68, blue: 0.58)

    /// Soft buttery yellow for profile total stars cards.
    static let dictionaryYellow = Color(red: 0.98, green: 0.94, blue: 0.78)
    static let dictionaryYellowDepth = Color(red: 0.86, green: 0.78, blue: 0.50)
    static let dictionaryYellowIcon = Color(red: 0.88, green: 0.68, blue: 0.14)

    /// Soft peach orange for profile daily streak cards.
    static let dictionaryOrange = Color(red: 0.99, green: 0.90, blue: 0.80)
    static let dictionaryOrangeDepth = Color(red: 0.88, green: 0.68, blue: 0.48)
    static let dictionaryOrangeIcon = Color(red: 0.94, green: 0.52, blue: 0.22)
}

// MARK: - View helpers

// MARK: - Chrome content sheet (Signs + Profile)

struct BrandChromePanel<Content: View>: View {
    private let topCornerRadius: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
            .fill(Brand.chrome)
            .elevation(.navigationPanel)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
            .stroke(Brand.divider.opacity(0.85), lineWidth: 1)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Full-screen pastel world background (home + tabs).
    func brandCanvasBackground() -> some View {
        background(HomeWorldBackground().ignoresSafeArea())
    }

    /// Soft blue gradient at the top of scroll content / headers.
    func brandHeaderWash(height: CGFloat = 120) -> some View {
        background(alignment: .top) {
            LinearGradient(
                colors: [Brand.soft.opacity(0.55), Brand.canvas.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}
