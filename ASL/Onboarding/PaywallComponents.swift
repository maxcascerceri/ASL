//
//  PaywallComponents.swift
//  ASL
//

import SwiftUI

enum PaywallMetrics {
    static let mascotSize: CGFloat = 188
    static let headlineSize: CGFloat = 32
    static let subheadlineSize: CGFloat = 17
    static let heroPriceSize: CGFloat = 21
    static let heroPriceUnitSize: CGFloat = 13
    static let planTitleSize: CGFloat = 15
    static let planDetailSize: CGFloat = 12
    static let badgeFontSize: CGFloat = 10
    static let benefitFontSize: CGFloat = 15
    static let benefitIconSize: CGFloat = 17
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let cardTopInsetForBadges: CGFloat = 8
    static let badgeOverlap: CGFloat = 7
    static let planCardMinHeight: CGFloat = 82
    static let trialButtonHeight: CGFloat = 56
    static let trialButtonCornerRadius: CGFloat = 18
    static let trialButtonDepth: CGFloat = 5
    static let contentMaxWidth: CGFloat = 380
}

private enum PaywallAccent {
    static let fill = Brand.primary
    static let shadow = Brand.primaryShadow
}

private enum PaywallMedia {
    static var mascotImageName: String {
        UnitMascot.imageName(for: "p1-u71") ?? UnitMascot.stoneCompleteCelebrationImageName
    }
}

// MARK: - Centered hero

struct PaywallCenteredHero: View {
    let headline: String
    let subheadline: String
    var isVisible: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(PaywallMedia.mascotImageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PaywallMetrics.mascotSize,
                    height: PaywallMetrics.mascotSize
                )

            VStack(spacing: 10) {
                Text(headline)
                    .font(.asl(PaywallMetrics.headlineSize, weight: .bold, design: .display))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subheadline)
                    .font(.asl(PaywallMetrics.subheadlineSize, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: PaywallMetrics.contentMaxWidth)
        }
        .frame(maxWidth: .infinity)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
    }
}

// MARK: - Badges

struct PaywallCornerBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.asl(PaywallMetrics.badgeFontSize, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(PaywallAccent.fill)
            )
    }
}

// MARK: - Plan cards

struct PaywallPlanCardModel: Equatable {
    let label: String
    let priceAmount: String
    let priceUnit: String
    let detail: String
    let cornerBadge: String?
    let usesAccentFill: Bool
}

enum PaywallPlanCardContent {
    static let yearly = PaywallPlanCardModel(
        label: "Yearly · Best value",
        priceAmount: OnboardingPaywallPricing.yearlyWeeklyBreakdown,
        priceUnit: "/week",
        detail: "\(OnboardingPaywallPricing.formattedYearlyPrice)/year · \(OnboardingPaywallPricing.savingsBadgeText)",
        cornerBadge: "7 DAYS FREE",
        usesAccentFill: true
    )

    static let weekly = PaywallPlanCardModel(
        label: "Weekly · Most flexible",
        priceAmount: OnboardingPaywallPricing.formattedWeeklyPrice,
        priceUnit: "/week",
        detail: "Billed weekly · \(OnboardingPaywallPricing.trialDays)-day free trial",
        cornerBadge: "NO COMMITMENT",
        usesAccentFill: false
    )
}

struct PaywallPlanCard: View {
    let model: PaywallPlanCardModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: select) {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: 12) {
                    planTextStack

                    Spacer(minLength: 8)

                    PaywallPlanRadio(isSelected: isSelected)
                }
                .padding(PaywallMetrics.cardPadding)
                .padding(.top, model.cornerBadge == nil ? 0 : PaywallMetrics.cardTopInsetForBadges)
                .frame(minHeight: PaywallMetrics.planCardMinHeight, alignment: .center)

                if let cornerBadge = model.cornerBadge {
                    PaywallCornerBadge(text: cornerBadge)
                        .padding(.trailing, 12)
                        .offset(y: -PaywallMetrics.badgeOverlap)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { cardBackground }
            .contentShape(
                RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var planTextStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.label)
                .font(.asl(PaywallMetrics.planTitleSize, weight: .bold))
                .foregroundStyle(Brand.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(model.priceAmount)
                    .font(.asl(PaywallMetrics.heroPriceSize, weight: .bold))
                    .foregroundStyle(Brand.textPrimary)
                Text(model.priceUnit)
                    .font(.asl(PaywallMetrics.heroPriceUnitSize, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }

            Text(model.detail)
                .font(.asl(PaywallMetrics.planDetailSize, weight: .medium))
                .foregroundStyle(Brand.secondaryLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func select() {
        guard !isSelected else { return }
        Haptics.tap()
        onSelect()
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius, style: .continuous)
            .fill(model.usesAccentFill ? PaywallAccent.fill.opacity(0.08) : Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(OnboardingSelectionStyle.selectedBorderGradient)
                            : AnyShapeStyle(OnboardingSelectionStyle.unselectedBorder),
                        lineWidth: isSelected
                            ? OnboardingSelectionStyle.selectedBorderWidth
                            : OnboardingSelectionStyle.unselectedBorderWidth
                    )
            }
    }
}

private struct PaywallPlanRadio: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(isSelected ? OnboardingSelectionStyle.checkFill : OnboardingSelectionStyle.unselectedBorder)
    }
}

// MARK: - Benefits

struct PaywallBenefit: Identifiable, Equatable {
    var id: String { text }
    let text: String
    let systemImage: String
}

struct PaywallBenefitsList: View {
    let benefits: [PaywallBenefit]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: benefit.systemImage)
                        .font(.system(size: PaywallMetrics.benefitIconSize, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                        .frame(width: 22, alignment: .center)
                        .padding(.top, 1)

                    Text(benefit.text)
                        .font(.asl(PaywallMetrics.benefitFontSize, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: PaywallMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius, style: .continuous)
                .fill(Brand.soft.opacity(0.45))
        )
        .overlay {
            RoundedRectangle(cornerRadius: PaywallMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(Brand.divider.opacity(0.9), lineWidth: 1)
        }
    }
}

// MARK: - Trial CTA

struct PaywallTrialButton: View {
    let title: String
    let action: () -> Void

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    private var showsPressed: Bool {
        isPressed || releasePressed
    }

    private var depthColor: Color {
        PaywallAccent.shadow
    }

    private var faceOffset: CGFloat {
        showsPressed ? 3 : 0
    }

    private var depthOffset: CGFloat {
        showsPressed ? 1.5 : PaywallMetrics.trialButtonDepth
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: PaywallMetrics.trialButtonCornerRadius, style: .continuous)
                .fill(depthColor)
                .frame(height: PaywallMetrics.trialButtonHeight)
                .offset(y: depthOffset)

            RoundedRectangle(cornerRadius: PaywallMetrics.trialButtonCornerRadius, style: .continuous)
                .fill(PaywallAccent.fill)
                .frame(height: PaywallMetrics.trialButtonHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: PaywallMetrics.trialButtonCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    Text(title)
                        .font(.asl(.button))
                        .foregroundStyle(.white)
                }
                .offset(y: faceOffset)
        }
        .frame(maxWidth: PaywallMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .frame(
            height: PaywallMetrics.trialButtonHeight + PaywallMetrics.trialButtonDepth,
            alignment: .top
        )
        .scaleEffect(showsPressed ? 0.985 : 1)
        .elevation(.raisedControl(tint: depthColor, isPressed: showsPressed))
        .animation(pressAnimation, value: showsPressed)
        .contentShape(Rectangle())
        .gesture(pressGesture)
        .accessibilityAddTraits(.isButton)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                state = true
            }
            .onEnded { _ in
                Haptics.tap()
                releasePressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    releasePressed = false
                }
                action()
            }
    }

    private var pressAnimation: Animation {
        showsPressed
            ? .easeOut(duration: 0.04)
            : .spring(response: 0.18, dampingFraction: 0.72)
    }
}

// MARK: - Trust + footer

struct PaywallTrustStack: View {
    let selectedPlan: OnboardingPaywallPlan
    let onPrivacy: () -> Void
    let onTerms: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(OnboardingCopy.paywallBillingMicrocopy(plan: selectedPlan))
                .font(.asl(14, weight: .medium))
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
                .animation(.easeOut(duration: 0.12), value: selectedPlan)

            HStack(spacing: 16) {
                PaywallFooterLink(title: "Privacy", action: onPrivacy)
                PaywallFooterLink(title: "Terms", action: onTerms)
                PaywallFooterLink(title: "Restore", action: onRestore)
            }
        }
        .frame(maxWidth: PaywallMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct PaywallFooterLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.asl(14, weight: .regular))
                .foregroundStyle(Brand.tertiaryLabel)
        }
        .buttonStyle(.plain)
    }
}
