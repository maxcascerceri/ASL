//
//  RootView.swift
//  ASL
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var subscriptionStore: ASLSubscriptionStore
    @StateObject private var store = ASLDataStore()
    @State private var onboardingComplete = ASLOnboarding.isComplete
    @State private var showLaunchSplash = true
    #if DEBUG
    @State private var debugReplayOnboarding = ASLPremiumAccess.isDebugReplayOnboardingActive
    #endif

    private var hasPremium: Bool {
        #if DEBUG
        ASLPremiumAccess.hasMockAccess || subscriptionStore.hasPremium
        #else
        subscriptionStore.hasPremium
        #endif
    }

    var body: some View {
        ZStack {
            mainContent

            if showLaunchSplash {
                OnboardingSplashView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLaunchSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .tint(Brand.primary)
        .foregroundStyle(Brand.textPrimary)
        .onAppear {
            ASLOnboarding.markLaunchedIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: ASLOnboarding.debugResetNotification)) { _ in
            onboardingComplete = ASLOnboarding.isComplete
            #if DEBUG
            debugReplayOnboarding = ASLPremiumAccess.isDebugReplayOnboardingActive
            #endif
            Task {
                await subscriptionStore.refreshCustomerInfo()
            }
        }
    }

    private func exitDebugOnboardingPreview() {
        #if DEBUG
        ASLPremiumAccess.endDebugOnboardingReplay()
        debugReplayOnboarding = false
        onboardingComplete = ASLOnboarding.isComplete
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            #if DEBUG
            if debugReplayOnboarding {
                onboardingExperience
            } else if hasPremium {
                mainAppContent
            } else if onboardingComplete {
                OnboardingPaywallView(
                    profile: ASLOnboarding.loadProfile(),
                    progress: 1,
                    onTrialStarted: completePurchaseAndSeedStars
                )
            } else {
                onboardingExperience
            }
            #else
            if hasPremium {
                mainAppContent
            } else if onboardingComplete {
                OnboardingPaywallView(
                    profile: ASLOnboarding.loadProfile(),
                    progress: 1,
                    onTrialStarted: completePurchaseAndSeedStars
                )
            } else {
                onboardingExperience
            }
            #endif
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if debugReplayOnboarding {
                Button("Exit preview") {
                    exitDebugOnboardingPreview()
                }
                .font(.asl(12, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .padding(.trailing, 12)
            }
        }
        #endif
    }

    private var mainAppContent: some View {
        ContentView()
            .environmentObject(store)
    }

    @ViewBuilder
    private var onboardingExperience: some View {
        if onboardingComplete {
            OnboardingPaywallView(
                profile: ASLOnboarding.loadProfile(),
                progress: 1,
                onTrialStarted: completePurchaseAndSeedStars
            )
        } else {
            OnboardingFlowView(
                onReachPaywall: {
                    ASLOnboarding.markComplete()
                },
                onTrialStarted: completePurchaseAndSeedStars
            )
            .environmentObject(store)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func completePurchaseAndSeedStars() {
        #if DEBUG
        ASLPremiumAccess.endDebugOnboardingReplay()
        debugReplayOnboarding = false
        #endif
        guard hasPremium else { return }
        store.applyOnboardingTrialRewards()
        UnitMascot.prepareHomeIntroAfterOnboarding()
    }
}

#Preview {
    RootView()
        .environmentObject(ASLSubscriptionStore.shared)
}
