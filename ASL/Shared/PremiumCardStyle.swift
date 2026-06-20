//
//  PremiumCardStyle.swift
//  ASL
//
//  Elevated cards and lesson nodes — soft depth and subtle shadows (no light rim).
//

import SwiftUI
import UIKit

// MARK: - Metrics

enum PremiumCardMetrics {
    static let cornerRadius: CGFloat = 26
    static let cornerRadiusMedium: CGFloat = 24
    static let cornerRadiusCompact: CGFloat = 20

    /// Bottom slab height — premium raised, not arcade chunky.
    static let depth: CGFloat = 4
    static let pressedDepthOffset: CGFloat = 1
    static let pressedFaceOffset: CGFloat = 3
    static let pressedScale: CGFloat = 0.985
    static let borderWidth: CGFloat = 1

    static var pressAnimation: Animation {
        .spring(response: 0.2, dampingFraction: 0.72)
    }
}

enum PremiumLessonNodeMetrics {
    static let width: CGFloat = 104
    static let height: CGFloat = 88
    static let depth: CGFloat = 10
    static let pressedFaceOffset: CGFloat = 7
    static let pressedDepth: CGFloat = 3.5
    static let faceStrokeWidth: CGFloat = 1
}

// MARK: - Color helpers

enum PremiumCardStyle {
    /// A slightly darker, still-soft ramp derived from the face color — not a harsh shadow slab.
    static func softDepth(for fill: Color, hint shadow: Color? = nil, mix: Double = 0.22) -> Color {
        let shade = shadow ?? Brand.ink.opacity(0.45)
        return fill.mix(with: shade, by: mix)
    }

    /// Rim / bottom slab for lesson stones — slightly richer than generic cards.
    static func lessonStoneDepth(for fill: Color, hint shadow: Color) -> Color {
        softDepth(for: fill, hint: shadow, mix: 0.28)
    }

    /// Light gray bottom slab for white/chrome cards — same raised lip as colored cards.
    static func whiteCardDepth(for fill: Color = Brand.chrome) -> Color {
        softDepth(for: fill, hint: Brand.divider, mix: 0.48)
    }

    /// Hairline edge so white card faces don't melt into the page background.
    static var whiteCardBorder: Color {
        Brand.divider.opacity(0.85)
    }
}

// MARK: - Colored card

/// Raised card with a tinted face and soft bottom depth (unit cards, practice modes, categories).
struct PremiumColoredCard<Content: View>: View {
    let fill: Color
    var depthHint: Color? = nil
    var depthMix: Double = 0.22
    var slabDepth: CGFloat = PremiumCardMetrics.depth
    var cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusMedium
    var isPressed: Bool
    @ViewBuilder var content: () -> Content

    private var depthColor: Color {
        PremiumCardStyle.softDepth(for: fill, hint: depthHint, mix: depthMix)
    }

    var body: some View {
        let faceOffset = isPressed ? PremiumCardMetrics.pressedFaceOffset : 0
        let depthOffset = isPressed ? PremiumCardMetrics.pressedDepthOffset : slabDepth

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .offset(y: faceOffset)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(depthColor)
                    .offset(y: depthOffset)
            }
            .padding(.bottom, slabDepth)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scaleEffect(isPressed ? PremiumCardMetrics.pressedScale : 1)
            .elevation(.chapterCard(tint: fill))
            .animation(PremiumCardMetrics.pressAnimation, value: isPressed)
    }
}

// MARK: - White card

/// Raised white / chrome card (daily practice tasks, neutral lists).
struct PremiumWhiteCard<Content: View>: View {
    var fill: Color = Brand.chrome
    var cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusCompact
    var isPressed: Bool
    @ViewBuilder var content: () -> Content

    private var depthColor: Color {
        PremiumCardStyle.whiteCardDepth(for: fill)
    }

    var body: some View {
        let faceOffset = isPressed ? PremiumCardMetrics.pressedFaceOffset : 0
        let depthOffset = isPressed ? PremiumCardMetrics.pressedDepthOffset : PremiumCardMetrics.depth

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                PremiumCardStyle.whiteCardBorder,
                                lineWidth: PremiumCardMetrics.borderWidth
                            )
                    }
                    .offset(y: faceOffset)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(depthColor)
                    .offset(y: depthOffset)
            }
            .padding(.bottom, PremiumCardMetrics.depth)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scaleEffect(isPressed ? PremiumCardMetrics.pressedScale : 1)
            .elevation(.chapterCard(tint: fill))
            .animation(PremiumCardMetrics.pressAnimation, value: isPressed)
    }
}

// MARK: - Lesson node

/// Wide lesson stone — tactile puck with soft depth, not an arcade slab.
struct PremiumLessonNode<Glyph: View>: View {
    let faceColor: Color
    let rimColor: Color
    var strokeColor: Color = Color.black.opacity(0.06)
    var isPressed: Bool
    @ViewBuilder var glyph: () -> Glyph

    private let width = PremiumLessonNodeMetrics.width
    private let height = PremiumLessonNodeMetrics.height
    private let depth = PremiumLessonNodeMetrics.depth

    var body: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(rimColor)
                .frame(width: width, height: height)
                .offset(y: isPressed ? PremiumLessonNodeMetrics.pressedDepth : depth)

            Ellipse()
                .fill(faceColor)
                .frame(width: width, height: height)
                .overlay {
                    Ellipse()
                        .strokeBorder(strokeColor, lineWidth: PremiumLessonNodeMetrics.faceStrokeWidth)
                        .allowsHitTesting(false)
                }
                .offset(y: isPressed ? PremiumLessonNodeMetrics.pressedFaceOffset : 0)

            glyph()
                .frame(width: width, height: height)
                .offset(y: isPressed ? PremiumLessonNodeMetrics.pressedFaceOffset : 0)
        }
        .frame(width: width, height: height + depth, alignment: .top)
    }
}

extension Color {
    /// Linear RGB blend — used for card faces and in-progress lesson stones.
    func mix(with other: Color, by amount: Double) -> Color {
        let t = max(0, min(1, amount))
        let ui1 = UIColor(self)
        let ui2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1 + (a2 - a1) * t)
        )
    }

    /// Opaque blend for in-progress lesson stone faces.
    static func mixStone(base: Color, fill: Color, progress: Double) -> Color {
        let p = max(0, min(1, progress))
        guard p > 0 else { return base }
        guard p < 1 else { return fill }
        let curved = pow(p, 0.65)
        return base.mix(with: fill, by: curved)
    }
}

// MARK: - Progress bar

enum PremiumProgressBarMetrics {
    static let lessonBarHeight: CGFloat = 18
    static let previewBarHeight: CGFloat = 18
    static let minFillWidth: CGFloat = 14
}

/// Neutral recessed track for lesson and preview progress bars.
struct PremiumProgressBarTrack: View {
    var height: CGFloat = PremiumProgressBarMetrics.lessonBarHeight

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Brand.divider.opacity(0.48),
                        Brand.divider.opacity(0.66),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
    }
}

/// Glossy, dimensional fill — one continuous vertical ramp (shine → body → soft depth).
struct PremiumProgressBarFill: View {
    let color: Color
    var shadowColor: Color? = nil
    var height: CGFloat = PremiumProgressBarMetrics.lessonBarHeight

    private var depthColor: Color {
        let base = shadowColor ?? PremiumCardStyle.softDepth(for: color, mix: 0.28)
        return color.mix(with: base, by: 0.50)
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: color.mix(with: .white, by: 0.36), location: 0),
                        .init(color: color.mix(with: .white, by: 0.12), location: 0.26),
                        .init(color: color, location: 0.52),
                        .init(color: color, location: 0.82),
                        .init(color: depthColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
    }
}

// MARK: - Pastel cards (Signs dictionary + Profile stats)

enum PastelCardMetrics {
    static let cardHeight: CGFloat = 116
    static let statCardHeight: CGFloat = 116
    static let compactStatCardHeight: CGFloat = 88
    static let profileStatCardHeight: CGFloat = 104
    static let profileStatIconLabelSpacing: CGFloat = 16
    static let profileStatColumnSpacing: CGFloat = 16
    /// Optical nudge so the stat value aligns with the icon’s visual center.
    static let profileStatValueCenterOffset: CGFloat = 4
    static let cornerRadius: CGFloat = 20
    static let browseIconSize: CGFloat = 38
    static let statIconSize: CGFloat = 34
    static let heroIconSize: CGFloat = 68
    static let titleFontSize: CGFloat = 15
    static let heroTitleFontSize: CGFloat = 19
    static let statValueFontSize: CGFloat = 22
    static let profileLabelFontSize: CGFloat = 17
    static let contentPadding: CGFloat = 10
    static let heroContentPadding: CGFloat = 14
    static let iconPadding: CGFloat = 12
    static let heroIconPadding: CGFloat = 18
    static let depthMix: Double = 0.46
    static let slabDepth: CGFloat = 5.5
    static let iconOutlineWidth: CGFloat = 1.75
}

struct PastelPalette {
    let fill: Color
    let depth: Color
    let iconTint: Color

    static let signsLearned = PastelPalette(
        fill: Brand.dictionaryBlue,
        depth: Brand.dictionaryBlueDepth,
        iconTint: Brand.dictionaryBlueIcon
    )

    static let totalStars = PastelPalette(
        fill: Brand.dictionaryYellow,
        depth: Brand.dictionaryYellowDepth,
        iconTint: Brand.dictionaryYellowIcon
    )

    /// Profile Signs stat card — pastel face with brand-blue icon (matches home header).
    static let profileSigns = PastelPalette(
        fill: Brand.dictionaryBlue,
        depth: Brand.dictionaryBlueDepth,
        iconTint: Brand.primary
    )

    /// Profile Stars stat card — pastel face with medal gold icon.
    static let profileStars = PastelPalette(
        fill: Brand.dictionaryYellow,
        depth: Brand.dictionaryYellowDepth,
        iconTint: UnitPalette.profileStars.color
    )

    static let dailyStreak = PastelPalette(
        fill: Brand.dictionaryOrange,
        depth: Brand.dictionaryOrangeDepth,
        iconTint: Brand.dictionaryOrangeIcon
    )

    static func dictionaryBrowse(at index: Int) -> PastelPalette {
        index.isMultiple(of: 2) ? signsLearned : dictionaryMint
    }

    static let dictionaryMint = PastelPalette(
        fill: Brand.dictionaryMint,
        depth: Brand.dictionaryMintDepth,
        iconTint: Brand.dictionaryMintIcon
    )
}

struct PastelPillLabel: View {
    let title: String
    var fontSize: CGFloat = PastelCardMetrics.titleFontSize
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 5

    var body: some View {
        Text(title)
            .font(.asl(fontSize, weight: .semibold, design: .ui))
            .foregroundStyle(Brand.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white)
            }
    }
}

struct PastelIconWhiteOutline: ViewModifier {
    var strokeWidth: CGFloat = PastelCardMetrics.iconOutlineWidth

    func body(content: Content) -> some View {
        let w = strokeWidth
        content
            .shadow(color: .white, radius: 0, x: 0, y: -w)
            .shadow(color: .white, radius: 0, x: 0, y: w)
            .shadow(color: .white, radius: 0, x: -w, y: 0)
            .shadow(color: .white, radius: 0, x: w, y: 0)
            .shadow(color: .white, radius: 0, x: -w, y: -w)
            .shadow(color: .white, radius: 0, x: w, y: -w)
            .shadow(color: .white, radius: 0, x: -w, y: w)
            .shadow(color: .white, radius: 0, x: w, y: w)
    }
}

extension View {
    func pastelIconWhiteOutline(
        strokeWidth: CGFloat = PastelCardMetrics.iconOutlineWidth
    ) -> some View {
        modifier(PastelIconWhiteOutline(strokeWidth: strokeWidth))
    }
}
