//
//  RootView.swift
//  ASL
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = ASLDataStore()
    @State private var hasPremium = ASLPremiumAccess.hasAccess
    @State private var onboardingComplete = ASLOnboarding.isComplete
    @State private var showLaunchSplash = true

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
            hasPremium = ASLPremiumAccess.hasAccess
            onboardingComplete = ASLOnboarding.isComplete
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if hasPremium {
                ContentView()
                    .environmentObject(store)
            } else if onboardingComplete {
                OnboardingPaywallView(
                    profile: ASLOnboarding.loadProfile(),
                    progress: 1,
                    onTrialStarted: activateTrialAndSeedStars
                )
            } else {
                OnboardingFlowView(
                    onReachPaywall: {
                        ASLOnboarding.markComplete()
                    },
                    onTrialStarted: activateTrialAndSeedStars
                )
                .environmentObject(store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func activateTrialAndSeedStars() {
        ASLPremiumAccess.activateMockTrial()
        store.applyOnboardingTrialRewards()
        UnitMascot.prepareHomeIntroAfterOnboarding()
        hasPremium = true
    }
}

#Preview {
    RootView()
}
