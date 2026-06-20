//
//  OnboardingPaywallView.swift
//  ASL
//

import SwiftUI

enum OnboardingPaywallPricing {
    static let yearlyPrice: Double = 49.99
    static let weeklyPrice: Double = 9.99
    static let trialDays = 7

    static var formattedYearlyPrice: String { "$49.99" }
    static var formattedWeeklyPrice: String { "$9.99" }

    static var yearlyWeeklyBreakdown: String {
        String(format: "$%.2f", yearlyPrice / 52.0)
    }

    static var savingsPercent: Int {
        let weeklyAnnual = weeklyPrice * 52.0
        guard weeklyAnnual > 0 else { return 0 }
        return Int(((weeklyAnnual - yearlyPrice) / weeklyAnnual * 100).rounded())
    }

    static var savingsBadgeText: String {
        "SAVE \(savingsPercent)%"
    }
}

enum OnboardingPaywallPlan: String, CaseIterable, Identifiable {
    case yearly
    case weekly

    var id: String { rawValue }

    var trialLabel: String {
        "\(OnboardingPaywallPricing.trialDays)-day free trial"
    }

    /// Stub for future StoreKit product IDs.
    var productId: String {
        switch self {
        case .yearly: return "asl.premium.yearly"
        case .weekly: return "asl.premium.weekly"
        }
    }
}

struct OnboardingPaywallView: View {
    let profile: OnboardingProfile
    let progress: Double
    let onTrialStarted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: OnboardingPaywallPlan = .yearly
    @State private var heroIn = false
    @State private var benefitsIn = false
    @State private var plansIn = false
    @State private var actionIn = false

    var body: some View {
        Color.white.ignoresSafeArea()
            .overlay {
                if dynamicTypeSize >= .accessibility1 {
                    paywallLayout(scrollable: true)
                } else {
                    ViewThatFits(in: .vertical) {
                        paywallLayout(scrollable: false)
                        paywallLayout(scrollable: true)
                    }
                }
            }
            .onAppear {
                runAppearAnimation()
            }
    }

    private func paywallLayout(scrollable: Bool) -> some View {
        VStack(spacing: 0) {
            if scrollable {
                ScrollView {
                    paywallContent
                        .padding(.bottom, 8)
                }
            } else {
                paywallContent
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var paywallContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                PaywallCenteredHero(
                    headline: OnboardingCopy.paywallHeadline(profile: profile),
                    subheadline: OnboardingCopy.paywallSubheadline(profile: profile),
                    isVisible: heroIn
                )
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            purchaseBlock
        }
        .padding(.horizontal, 24)
    }

    private var purchaseBlock: some View {
        VStack(spacing: 16) {
            PaywallBenefitsList(benefits: OnboardingCopy.paywallBenefits(profile: profile))
                .opacity(benefitsIn ? 1 : 0)
                .offset(y: benefitsIn ? 0 : 8)

            plansBlock
                .opacity(plansIn ? 1 : 0)
                .offset(y: plansIn ? 0 : 8)

            Text(OnboardingCopy.paywallNoPaymentToday)
                .font(.asl(16, weight: .bold))
                .foregroundStyle(Brand.primary)
                .multilineTextAlignment(.center)
                .opacity(actionIn ? 1 : 0)

            PaywallTrialButton(title: OnboardingCopy.startFreeTrial, action: onTrialStarted)
                .opacity(actionIn ? 1 : 0)
                .offset(y: actionIn ? 0 : 6)

            PaywallTrustStack(
                selectedPlan: selectedPlan,
                onPrivacy: { openLegalLink(ASLLegalLinks.privacyPolicy) },
                onTerms: { openLegalLink(ASLLegalLinks.termsOfUse) },
                onRestore: {}
            )
            .opacity(actionIn ? 1 : 0)
        }
        .padding(.bottom, 12)
    }

    private var plansBlock: some View {
        VStack(spacing: 10) {
            PaywallPlanCard(
                model: PaywallPlanCardContent.weekly,
                isSelected: selectedPlan == .weekly
            ) {
                selectedPlan = .weekly
            }

            PaywallPlanCard(
                model: PaywallPlanCardContent.yearly,
                isSelected: selectedPlan == .yearly
            ) {
                selectedPlan = .yearly
            }
        }
        .animation(.easeOut(duration: 0.12), value: selectedPlan)
    }

    private func runAppearAnimation() {
        if reduceMotion {
            heroIn = true
            benefitsIn = true
            plansIn = true
            actionIn = true
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            heroIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.28)) {
                benefitsIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                plansIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.28)) {
                actionIn = true
            }
        }
    }

    private func openLegalLink(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}
