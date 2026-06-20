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

    @EnvironmentObject private var subscriptionStore: ASLSubscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPlan: OnboardingPaywallPlan = .yearly
    @State private var heroIn = false
    @State private var benefitsIn = false
    @State private var plansIn = false
    @State private var actionIn = false

    private var pricing: PaywallPricingSnapshot {
        subscriptionStore.pricing
    }

    private var isBusy: Bool {
        subscriptionStore.isPurchasing || subscriptionStore.isRestoring
    }

    private var canPurchase: Bool {
        !isBusy && subscriptionStore.package(for: selectedPlan) != nil
    }

    private var trialButtonOpacity: Double {
        if subscriptionStore.isPurchasing { return 1 }
        if canPurchase { return 1 }
        return 0.55
    }

    private var trialButtonTitle: String {
        if subscriptionStore.isPurchasing {
            return "Starting trial…"
        }
        if subscriptionStore.isLoadingOfferings {
            return "Loading plans…"
        }
        return OnboardingCopy.startFreeTrial
    }

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
                Task {
                    await subscriptionStore.loadOfferings()
                }
            }
            .alert(
                "Subscription",
                isPresented: Binding(
                    get: { subscriptionStore.purchaseError != nil },
                    set: { isPresented in
                        if !isPresented {
                            subscriptionStore.purchaseError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    subscriptionStore.purchaseError = nil
                }
            } message: {
                Text(subscriptionStore.purchaseError ?? "")
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

            PaywallTrialButton(
                title: trialButtonTitle,
                isLoading: subscriptionStore.isPurchasing,
                action: startTrial
            )
                .opacity(actionIn ? trialButtonOpacity : 0)
                .offset(y: actionIn ? 0 : 6)
                .allowsHitTesting(canPurchase)
                .animation(nil, value: subscriptionStore.isPurchasing)

            PaywallTrustStack(
                selectedPlan: selectedPlan,
                pricing: pricing,
                onRestore: restorePurchases
            )
            .opacity(actionIn ? 1 : 0)
        }
        .padding(.bottom, 12)
    }

    private var plansBlock: some View {
        VStack(spacing: 10) {
            PaywallPlanCard(
                model: PaywallPlanCardContent.weekly(from: pricing),
                isSelected: selectedPlan == .weekly
            ) {
                selectedPlan = .weekly
            }

            PaywallPlanCard(
                model: PaywallPlanCardContent.yearly(from: pricing),
                isSelected: selectedPlan == .yearly
            ) {
                selectedPlan = .yearly
            }
        }
        .animation(.easeOut(duration: 0.12), value: selectedPlan)
        .animation(.easeOut(duration: 0.12), value: pricing)
    }

    private func startTrial() {
        Task {
            let purchased = await subscriptionStore.purchase(plan: selectedPlan)
            if purchased {
                onTrialStarted()
            }
        }
    }

    private func restorePurchases() {
        Task {
            let restored = await subscriptionStore.restore()
            if restored {
                onTrialStarted()
            }
        }
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
}
