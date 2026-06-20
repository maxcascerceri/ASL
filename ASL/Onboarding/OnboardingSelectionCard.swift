//
//  OnboardingSelectionCard.swift
//  ASL
//

import SwiftUI

enum OnboardingSelectionLayout {
    case leadingStacked
    case splitRow
}

enum OnboardingSelectionStyle {
    static let selectedBorderWidth: CGFloat = 3.5
    static let unselectedBorderWidth: CGFloat = 1.5
    static let checkFill = Color(red: 0.96, green: 0.74, blue: 0.26)
    static let unselectedBorder = Color(red: 0.90, green: 0.91, blue: 0.93)

    static var selectedBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.74, blue: 0.26),
                Brand.primary,
                Color(red: 0.55, green: 0.85, blue: 0.92),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func motivationIconGradient(for motivation: OnboardingMotivation) -> LinearGradient {
        switch motivation {
        case .family:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.55, blue: 0.66), Color(red: 0.98, green: 0.72, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .work:
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.68, blue: 0.22), Color(red: 0.99, green: 0.84, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .education:
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.78, blue: 0.72), Color(red: 0.98, green: 0.86, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .deaf:
            return LinearGradient(
                colors: [Color(red: 0.30, green: 0.76, blue: 0.78), Color(red: 0.98, green: 0.78, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting:
            return LinearGradient(
                colors: [Brand.primary, Color(red: 0.38, green: 0.78, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .fun:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.48, blue: 0.42), Color(red: 0.98, green: 0.72, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum SelectionCardColors {
    static let unselectedBorder = OnboardingSelectionStyle.unselectedBorder
}

private enum OnboardingSelectionCardMetrics {
    static let cornerRadius: CGFloat = 18
    static let titleFontSize: CGFloat = 17
    static let subtitleFontSize: CGFloat = 15
    static let symbolSize: CGFloat = 22
    static let symbolFrame: CGFloat = 36
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 18
    static let selectedScale: CGFloat = 1.02
}

struct OnboardingSelectionCard: View {
    let title: String
    var subtitle: String? = nil
    var symbolName: String? = nil
    var iconGradient: LinearGradient? = nil
    var layout: OnboardingSelectionLayout = .leadingStacked
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            rowContent
                .padding(.horizontal, OnboardingSelectionCardMetrics.horizontalPadding)
                .padding(.vertical, OnboardingSelectionCardMetrics.verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay { cardBorder }
                .scaleEffect(isSelected ? OnboardingSelectionCardMetrics.selectedScale : 1)
        }
        .buttonStyle(OnboardingSelectionCardPressStyle())
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
    }

    private var cardBackground: some View {
        RoundedRectangle(
            cornerRadius: OnboardingSelectionCardMetrics.cornerRadius,
            style: .continuous
        )
        .fill(Color.white)
    }

    private var cardBorder: some View {
        RoundedRectangle(
            cornerRadius: OnboardingSelectionCardMetrics.cornerRadius,
            style: .continuous
        )
        .strokeBorder(
            isSelected
                ? AnyShapeStyle(OnboardingSelectionStyle.selectedBorderGradient)
                : AnyShapeStyle(SelectionCardColors.unselectedBorder),
            lineWidth: isSelected
                ? OnboardingSelectionStyle.selectedBorderWidth
                : OnboardingSelectionStyle.unselectedBorderWidth
        )
    }

    @ViewBuilder
    private var rowContent: some View {
        switch layout {
        case .leadingStacked:
            stackedRow
        case .splitRow:
            splitRow
        }
    }

    private var stackedRow: some View {
        HStack(spacing: 14) {
            if let symbolName {
                iconView(symbolName: symbolName)
            }

            Text(title)
                .font(.asl(OnboardingSelectionCardMetrics.titleFontSize, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            checkmark
        }
    }

    private var splitRow: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.asl(OnboardingSelectionCardMetrics.titleFontSize, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let subtitle {
                Text(subtitle)
                    .font(.asl(OnboardingSelectionCardMetrics.subtitleFontSize, weight: .regular))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }

            checkmark
        }
    }

    @ViewBuilder
    private func iconView(symbolName: String) -> some View {
        let image = Image(systemName: symbolName)
            .font(.asl(OnboardingSelectionCardMetrics.symbolSize, weight: .semibold))
            .frame(
                width: OnboardingSelectionCardMetrics.symbolFrame,
                height: OnboardingSelectionCardMetrics.symbolFrame
            )

        if let iconGradient {
            image.foregroundStyle(iconGradient)
        } else {
            image.foregroundStyle(Brand.secondaryLabel)
        }
    }

    @ViewBuilder
    private var checkmark: some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(OnboardingSelectionStyle.checkFill)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            .transition(
                .scale(scale: 0.45, anchor: .center)
                    .combined(with: .opacity)
            )
        } else {
            Circle()
                .strokeBorder(SelectionCardColors.unselectedBorder, lineWidth: 1.5)
                .frame(width: 24, height: 24)
        }
    }
}

private struct OnboardingSelectionCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
