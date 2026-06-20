//
//  PracticeOptionCard.swift
//  ASL
//

import SwiftUI

private struct PracticeModePalette {
    let unitPalette: UnitPalette

    var fill: Color { unitPalette.color }
    var depth: Color { unitPalette.shadow }

    static func palette(for mode: PracticeMode) -> PracticeModePalette {
        switch mode {
        case .quiz:
            return PracticeModePalette(unitPalette: UnitPalette.palette(for: 1))
        case .flashcards:
            return PracticeModePalette(unitPalette: UnitPalette.palette(for: 4))
        case .vocabularyMatch:
            return PracticeModePalette(unitPalette: UnitPalette.palette(for: 2))
        case .spellYourName:
            return PracticeModePalette(unitPalette: UnitPalette.palette(for: 0))
        }
    }
}

private enum PracticeOptionCardMetrics {
    static let disabledFill = Color(red: 0.90, green: 0.91, blue: 0.94)
    static let disabledDepth = Color(red: 0.82, green: 0.84, blue: 0.88)
    static let disabledIconTint = Color(red: 0.62, green: 0.65, blue: 0.70)
}

struct PracticeOptionCard: View {
    let mode: PracticeMode
    var isEnabled: Bool = true
    var isPreparing: Bool = false
    let action: () -> Void

    @Environment(\.raisedCardPressed) private var isPressed

    private var palette: PracticeModePalette {
        PracticeModePalette.palette(for: mode)
    }

    private var isInteractive: Bool {
        isEnabled && !isPreparing
    }

    private var cardFill: Color {
        isInteractive ? palette.fill : PracticeOptionCardMetrics.disabledFill
    }

    private var cardDepth: Color {
        isInteractive ? palette.depth : PracticeOptionCardMetrics.disabledDepth
    }

    private var iconTint: Color {
        isInteractive ? palette.fill : PracticeOptionCardMetrics.disabledIconTint
    }

    private let cardHeight: CGFloat = 84

    var body: some View {
        Button(action: action) {
            PremiumColoredCard(
                fill: cardFill,
                depthHint: cardDepth,
                cornerRadius: PremiumCardMetrics.cornerRadiusMedium,
                isPressed: isPressed && isInteractive
            ) {
                cardContent
                    .frame(height: cardHeight)
            }
        }
        .buttonStyle(RaisedCardPressStyle())
        .disabled(!isInteractive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPreparing ? "\(mode.title). Preparing signs" : "\(mode.title). \(mode.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            PracticeOptionIcon(mode: mode, iconTint: iconTint)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .aslStyle(
                        .cardTitle,
                        surface: isInteractive ? .colored : .light,
                        variant: .compact
                    )
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                subtitleText
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    isInteractive ? .white.opacity(0.92) : Brand.secondaryLabel
                )
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var displaySubtitle: String {
        if isPreparing {
            return "Preparing signs…"
        }
        return mode.subtitle
    }

    private var subtitleText: some View {
        let surface: ASLTextSurface = isInteractive ? .colored : .light
        let font: Font = mode == .spellYourName
            ? .asl(13, weight: .regular)
            : .asl(.cardDescription, variant: .compact)

        return Text(displaySubtitle)
            .font(font)
            .foregroundStyle(ASLTextMetrics.foregroundStyle(for: .cardDescription, surface: surface))
            .lineSpacing(ASLTextMetrics.lineSpacing(for: .cardDescription))
    }
}

private struct PracticeOptionIcon: View {
    let mode: PracticeMode
    let iconTint: Color

    private var symbolName: String {
        switch mode {
        case .quiz: return "questionmark.circle.fill"
        case .flashcards: return "rectangle.on.rectangle.angled.fill"
        case .vocabularyMatch: return "link.circle.fill"
        case .spellYourName: return "person.text.rectangle.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)

            ASLIcon(
                source: .symbol(symbolName),
                role: .badgeDisc,
                tint: iconTint
            )
        }
        .frame(width: 46, height: 46)
    }
}
