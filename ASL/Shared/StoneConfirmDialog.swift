//
//  StoneConfirmDialog.swift
//  ASL
//

import SwiftUI

struct StoneConfirmScrim: View {
    var body: some View {
        Color.black.opacity(0.42)
            .ignoresSafeArea()
            .transition(.opacity)
    }
}

struct StoneConfirmDialog: View {
    let iconSystemName: String
    let title: String
    let message: String
    let primaryTitle: String
    let destructiveTitle: String
    let palette: Color
    let paletteShadow: Color
    let primaryAction: () -> Void
    let destructiveAction: () -> Void

    private enum Metrics {
        static let cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusMedium
        static let iconOuter: CGFloat = 80
        static let iconInner: CGFloat = 62
        static let accentBarWidth: CGFloat = 48
        static let accentBarHeight: CGFloat = 4
    }

    var body: some View {
        VStack(spacing: 22) {
            iconBadge

            VStack(spacing: 10) {
                Text(title)
                    .font(.asl(24, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.asl(16, weight: .medium))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                PressableAlertButton(action: primaryAction) { isPressed in
                    RaisedUnitButtonLabel(
                        title: primaryTitle,
                        color: palette,
                        depthColor: paletteShadow,
                        isPressed: isPressed,
                        height: 54,
                        depth: PremiumCardMetrics.depth
                    )
                }

                PressableAlertButton(action: destructiveAction) { isPressed in
                    RaisedUnitButtonLabel(
                        title: destructiveTitle,
                        color: Brand.chrome,
                        depthColor: PremiumCardStyle.whiteCardDepth(for: Brand.chrome),
                        foreground: Color.lessonCoralButton,
                        isPressed: isPressed,
                        height: 54,
                        depth: PremiumCardMetrics.depth
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(PremiumCardStyle.whiteCardBorder, lineWidth: 1)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: 340)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(PremiumCardStyle.whiteCardDepth(for: Brand.chrome))
                .offset(y: PremiumCardMetrics.depth)
        }
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Brand.chrome)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                        .strokeBorder(PremiumCardStyle.whiteCardBorder, lineWidth: PremiumCardMetrics.borderWidth)
                }
        }
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.mix(with: .white, by: 0.18),
                            palette,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: Metrics.accentBarWidth, height: Metrics.accentBarHeight)
                .padding(.top, 14)
        }
        .padding(.bottom, PremiumCardMetrics.depth)
        .elevation(.sheetModal)
        .padding(.horizontal, 24)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(palette.opacity(0.14))
                .frame(width: Metrics.iconOuter, height: Metrics.iconOuter)

            Circle()
                .fill(Brand.chrome)
                .frame(width: Metrics.iconInner, height: Metrics.iconInner)
                .overlay {
                    Circle()
                        .strokeBorder(palette.opacity(0.22), lineWidth: 2)
                }
                .elevation(.insetField)

            Image(systemName: iconSystemName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette)
        }
    }
}

struct ResetStoneConfirmCard: View {
    let palette: Color
    let paletteShadow: Color
    let keepGoing: () -> Void
    let reset: () -> Void

    var body: some View {
        StoneConfirmDialog(
            iconSystemName: "arrow.counterclockwise",
            title: "Reset this stone?",
            message: "Your progress on this stone will be cleared.",
            primaryTitle: "Continue",
            destructiveTitle: "Reset",
            palette: palette,
            paletteShadow: paletteShadow,
            primaryAction: keepGoing,
            destructiveAction: reset
        )
    }
}

struct LeaveStoneConfirmCard: View {
    let palette: Color
    let paletteShadow: Color
    var message: String = "Your progress is saved. You can pick up where you left off."
    let keepGoing: () -> Void
    let leave: () -> Void

    var body: some View {
        StoneConfirmDialog(
            iconSystemName: "hand.raised.fill",
            title: "Leave this stone?",
            message: message,
            primaryTitle: "Continue",
            destructiveTitle: "Leave",
            palette: palette,
            paletteShadow: paletteShadow,
            primaryAction: keepGoing,
            destructiveAction: leave
        )
    }
}

struct PressableAlertButton<Label: View>: View {
    let action: () -> Void
    let label: (Bool) -> Label

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping (Bool) -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label(isPressed || releasePressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onEnded { _ in
                        releasePressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            releasePressed = false
                        }
                        Haptics.tap()
                        action()
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}
