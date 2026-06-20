//
//  ProfileRaisedCard.swift
//  ASL
//

import SwiftUI
import UIKit

/// Continuous SF Symbol animation styles for profile stat badges.
enum ProfileIconAnimation {
    case handsClap
    case starTwinkle
    case flameFlicker

    var systemImage: String {
        switch self {
        case .handsClap:
            let candidates = ["hands.clap", "figure.american.sign.language", "hands.clap.fill", "hand.wave.fill"]
            return candidates.first(where: { UIImage(systemName: $0) != nil }) ?? "hand.wave.fill"
        case .starTwinkle:
            return "star.fill"
        case .flameFlicker:
            return "flame.fill"
        }
    }

    /// SF Symbol with a drawable variable value, when available on this OS.
    var variableSymbolName: String? {
        switch self {
        case .handsClap:
            return UIImage(systemName: "hands.clap") != nil ? "hands.clap" : nil
        case .flameFlicker:
            return UIImage(systemName: "flame") != nil ? "flame" : nil
        case .starTwinkle:
            return nil
        }
    }

    var usesVariableValue: Bool {
        variableSymbolName != nil
    }
}

/// Animated SF Symbol used inside profile icon badges.
struct ProfileAnimatedSymbol: View {
    let animation: ProfileIconAnimation
    let tint: Color
    var role: ASLIconRole = .badgeDisc
    var iconSize: CGFloat = 22
    var bounceValue: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animPhase = 0.0

    var body: some View {
        Group {
            if animation.usesVariableValue, let symbol = animation.variableSymbolName {
                ASLIcon(
                    source: .symbolVariable(symbol, value: animPhase),
                    role: role,
                    tint: tint,
                    bounceTrigger: bounceValue,
                    assetSize: iconSize
                )
            } else {
                baseImage
            }
        }
        .onAppear { startContinuousAnimation() }
        .onChange(of: reduceMotion) { _, isReduced in
            if animation.usesVariableValue {
                if isReduced {
                    stopContinuousAnimation()
                } else {
                    startContinuousAnimation()
                }
            }
        }
    }

    @ViewBuilder
    private var baseImage: some View {
        switch animation {
        case .flameFlicker, .handsClap:
            if reduceMotion {
                ASLIcon(
                    source: .symbol(animation.systemImage),
                    role: role,
                    tint: tint,
                    bounceTrigger: bounceValue,
                    assetSize: iconSize
                )
            } else {
                Image(systemName: animation.systemImage)
                    .font(.asl(iconSize, weight: ASLIconMetrics.weight(for: role)))
                    .symbolRenderingMode(ASLIconMetrics.renderingMode(for: role))
                    .foregroundStyle(tint)
                    .scaleEffect(ASLIconMetrics.opticalScale(for: role))
                    .symbolEffect(.bounce, value: bounceValue)
                    .symbolEffect(.bounce, options: .repeating.speed(repeatingSpeed))
            }
        case .starTwinkle:
            if reduceMotion {
                ASLIcon(
                    source: .symbol(animation.systemImage),
                    role: role,
                    tint: tint,
                    bounceTrigger: bounceValue,
                    assetSize: iconSize
                )
            } else {
                Image(systemName: animation.systemImage)
                    .font(.asl(iconSize, weight: ASLIconMetrics.weight(for: role)))
                    .symbolRenderingMode(ASLIconMetrics.renderingMode(for: role))
                    .foregroundStyle(tint)
                    .scaleEffect(ASLIconMetrics.opticalScale(for: role))
                    .symbolEffect(.bounce, value: bounceValue)
                    .symbolEffect(.pulse, options: .repeating.speed(repeatingSpeed))
            }
        }
    }

    private var repeatingSpeed: Double {
        switch animation {
        case .starTwinkle: return 0.75
        case .flameFlicker: return 0.55
        case .handsClap: return 0.65
        }
    }

    private func startContinuousAnimation() {
        guard animation.usesVariableValue, !reduceMotion else {
            if animation.usesVariableValue { animPhase = 1.0 }
            return
        }
        animPhase = 0
        let duration: Double = animation == .flameFlicker ? 0.55 : 0.38
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            animPhase = 1.0
        }
    }

    private func stopContinuousAnimation() {
        animPhase = animation.usesVariableValue ? 1.0 : 0
    }
}

/// Cream capsule behind stat numbers — matches Practice / Signs title pills.
struct ProfileCreamNumberPill: View {
    let value: Int
    var fontSize: CGFloat = 28

    var body: some View {
        Text("\(value)")
            .font(.asl(fontSize, weight: .semibold))
            .foregroundStyle(Brand.textPrimary)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: value)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Brand.cream.opacity(0.95))
            )
    }
}

/// Raised cream circle behind profile card icons — matches Practice option icons.
struct ProfileRaisedIconBadge: View {
    let animation: ProfileIconAnimation
    let tint: Color
    var size: CGFloat = 44
    var iconSize: CGFloat = 22
    var bounceValue: Int = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Brand.cream.opacity(0.92))

            ProfileAnimatedSymbol(
                animation: animation,
                tint: tint,
                iconSize: iconSize,
                bounceValue: bounceValue
            )
        }
        .frame(width: size, height: size)
    }
}

/// Shared 3D raised card shell for variable-height profile cards (streak, etc.).
struct ProfileRaisedCard<Content: View>: View {
    let fill: Color
    let depth: Color
    var cornerRadius: CGFloat = 22
    var contentPadding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    @Environment(\.raisedCardPressed) private var isPressed

    private var isVisuallyPressed: Bool { isPressed }

    var body: some View {
        PremiumColoredCard(
            fill: fill,
            depthHint: depth,
            cornerRadius: cornerRadius,
            isPressed: isVisuallyPressed
        ) {
            content()
                .padding(contentPadding)
        }
    }
}

enum ProfileCardPalette {
    static let medalsFill = Brand.chrome
    static let medalsDepth = Color(red: 0.78, green: 0.82, blue: 0.88)
}

/// Playful multi-stop gradient borders for profile stat cards (reference: white face + colorful rim).
enum ProfileCardBorderStyle {
    static let borderWidth: CGFloat = 3.5

    static var streak: LinearGradient {
        LinearGradient(
            colors: [
                UnitPalette.profileStreak.color,
                UnitPalette.profileStars.color,
                Color(red: 1.0, green: 0.55, blue: 0.66),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// White profile card with a thick gradient border and raised bottom depth.
struct ProfileBorderedCard<Content: View>: View {
    let borderGradient: LinearGradient
    var cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusMedium
    var borderWidth: CGFloat = ProfileCardBorderStyle.borderWidth
    var faceFill: Color = .white
    var isPressed: Bool = false
    @ViewBuilder var content: () -> Content

    private var depthColor: Color {
        PremiumCardStyle.whiteCardDepth(for: faceFill)
    }

    var body: some View {
        let faceOffset = isPressed ? PremiumCardMetrics.pressedFaceOffset : 0
        let depthOffset = isPressed ? PremiumCardMetrics.pressedDepthOffset : PremiumCardMetrics.depth

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(faceFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(borderGradient, lineWidth: borderWidth)
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
            .elevation(.chapterCard(tint: faceFill))
            .animation(PremiumCardMetrics.pressAnimation, value: isPressed)
    }
}

enum ProfileMetricLabelStyle {
    static let fontSize: CGFloat = 14

    static func label(_ text: String) -> some View {
        Text(text)
            .font(.asl(fontSize, weight: .semibold))
            .foregroundStyle(Brand.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
