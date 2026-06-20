//
//  ProfileMedalCell.swift
//  ASL
//

import SwiftUI

enum ProfileMedalState: Hashable {
    case earned
    case locked
}

struct ProfileMedalItem: Identifiable, Hashable {
    let definition: ASLMedalDefinition
    let state: ProfileMedalState
    /// 0…1 visual fill toward full color; earned medals are always 1.
    let progressFraction: Double

    var id: String { definition.id }

    var isUnlocked: Bool { state == .earned }

    var palette: UnitPalette {
        UnitPalette.medalPalette(for: definition)
    }
}

// MARK: - Unit-aligned medal colors

struct MedalColorStyle {
    let palette: UnitPalette

    var accent: Color { palette.color }

    static func style(for palette: UnitPalette) -> MedalColorStyle {
        MedalColorStyle(palette: palette)
    }
}

// MARK: - Circular medal

struct ProfileMedalCell: View {
    let item: ProfileMedalItem
    var discSize: CGFloat = 96
    var iconSize: CGFloat = 38
    var showsLabel: Bool = false
    /// Keeps every cell the same height so discs line up in horizontal rows.
    var usesFixedLabelSlot: Bool = false

    private static let labelSlotHeight: CGFloat = 36

    private var labelWidth: CGFloat { discSize + 12 }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ProfileMedalDisc(
                state: item.state,
                palette: item.palette,
                symbolName: item.definition.symbolName,
                progressFraction: item.progressFraction,
                discSize: discSize,
                iconSize: iconSize
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)

            if showsLabel || usesFixedLabelSlot {
                labelText
                    .frame(width: labelWidth, height: Self.labelSlotHeight, alignment: .top)
            }
        }
        .frame(width: labelWidth, alignment: .top)
    }

    @ViewBuilder
    private var labelText: some View {
        if showsLabel {
            Text(item.definition.title)
                .aslStyle(
                    .progressLabel,
                    variant: .prominent,
                    color: item.isUnlocked ? Brand.textPrimary : Brand.secondaryLabel.opacity(0.85)
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var accessibilityLabel: String {
        if item.isUnlocked {
            return "\(item.definition.title) medal earned"
        }
        if item.progressFraction > 0 {
            let percent = Int((item.progressFraction * 100).rounded())
            return "\(item.definition.title) medal in progress, \(percent) percent"
        }
        return "\(item.definition.title) medal locked"
    }
}

struct ProfileMedalDisc: View {
    let state: ProfileMedalState
    let palette: UnitPalette
    let symbolName: String
    var progressFraction: Double = 0
    var discSize: CGFloat = 96
    var iconSize: CGFloat = 38

    private static let grayscaleFace = Color(red: 0.86, green: 0.87, blue: 0.89)
    private static let grayscaleRim = Color(red: 0.74, green: 0.76, blue: 0.80)
    private static let depthOffset: CGFloat = 3.5

    private var progress: Double {
        if state == .earned { return 1 }
        return min(max(progressFraction, 0), 1)
    }

    private var isFullyColored: Bool {
        state == .earned || progress >= 0.999
    }

    private var coloredRim: Color {
        PremiumCardStyle.softDepth(for: palette.color, hint: palette.shadow)
    }

    private var grayscaleMaskHeight: CGFloat {
        discSize * (1 - progress)
    }

    private var iconColor: Color {
        if isFullyColored || progress > 0 { return .white }
        return Self.grayscaleRim
    }

    var body: some View {
        ZStack(alignment: .top) {
            coloredRimDisc

            coloredFaceDisc

            Image(systemName: symbolName)
                .font(.asl(iconSize, weight: .semibold, design: .ui))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconColor)
                .frame(width: discSize, height: discSize)
        }
        .frame(width: discSize, height: discSize + Self.depthOffset, alignment: .top)
    }

    private var coloredRimDisc: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(coloredRim)
                .frame(width: discSize, height: discSize)
                .offset(y: Self.depthOffset)

            if !isFullyColored {
                Circle()
                    .fill(Self.grayscaleRim)
                    .frame(width: discSize, height: discSize)
                    .mask(alignment: .top) { grayscaleTopMask }
                    .offset(y: Self.depthOffset)
            }
        }
    }

    private var coloredFaceDisc: some View {
        ZStack {
            Circle()
                .fill(palette.color)
                .frame(width: discSize, height: discSize)

            if !isFullyColored {
                Circle()
                    .fill(Self.grayscaleFace)
                    .frame(width: discSize, height: discSize)
                    .mask(alignment: .top) { grayscaleTopMask }
            }

            if isFullyColored {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: discSize, height: discSize)
                    .allowsHitTesting(false)
            }
        }
    }

    private var grayscaleTopMask: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white)
                .frame(height: grayscaleMaskHeight)
            Spacer(minLength: 0)
        }
        .frame(width: discSize, height: discSize)
    }
}

extension ProfileMedalItem {
    var accentColor: Color {
        palette.color
    }
}
