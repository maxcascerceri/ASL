//
//  MedalCelebrationPresenter.swift
//  ASL
//

import Combine
import SwiftUI

private struct MedalCelebrationPresenterModifier: ViewModifier {
    @ObservedObject var store: ASLDataStore
    @Binding var selectedTab: AppTab
    let isTabBarHidden: Bool

    @State private var presentedMedalCelebration: ASLMedalDefinition?
    @State private var deferredSettleWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presentedMedalCelebration) { definition in
                MedalUnlockCelebrationView(definition: definition) {
                    presentedMedalCelebration = nil
                    presentNextIfEligible()
                }
            }
            .onChange(of: store.medalEngine.hasPendingCelebration) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: store.isLessonMediaSessionActive) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: selectedTab) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: isTabBarHidden) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: store.homeUnitFlowBlocksMedalCelebrations) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: store.pendingDailyStreakCelebration?.dayKey) { _, _ in
                presentNextIfEligible()
            }
            .onChange(of: store.celebratedUnit?.id) { _, _ in
                presentNextIfEligible()
            }
            .onAppear {
                presentNextIfEligible()
            }
            .onReceive(store.medalEngine.objectWillChange) { _ in
                presentNextIfEligible()
            }
    }

    private func presentNextIfEligible() {
        deferredSettleWorkItem?.cancel()
        deferredSettleWorkItem = nil

        guard store.medalEngine.hasPendingCelebration else { return }
        guard presentedMedalCelebration == nil else { return }
        guard !store.isLessonMediaSessionActive else { return }
        guard !isTabBarHidden else { return }

        if store.medalEngine.isDeferredUntilHome {
            guard selectedTab == .home else { return }
            guard !store.homeUnitFlowBlocksMedalCelebrations else { return }

            let work = DispatchWorkItem {
                guard canPresentNow else { return }
                showNextMedal(clearDeferred: true)
            }
            deferredSettleWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            return
        }

        guard store.pendingDailyStreakCelebration == nil else { return }
        showNextMedal(clearDeferred: false)
    }

    private var canPresentNow: Bool {
        store.medalEngine.hasPendingCelebration
            && presentedMedalCelebration == nil
            && store.pendingDailyStreakCelebration == nil
            && !store.isLessonMediaSessionActive
            && !isTabBarHidden
            && selectedTab == .home
            && !store.homeUnitFlowBlocksMedalCelebrations
    }

    private func showNextMedal(clearDeferred: Bool) {
        guard store.medalEngine.hasPendingCelebration else { return }
        presentedMedalCelebration = store.medalEngine.consumeNextCelebration(from: store)
        if clearDeferred {
            store.medalEngine.clearDeferredUntilHome()
        }
    }
}

extension View {
    func medalCelebrationPresenter(
        store: ASLDataStore,
        selectedTab: Binding<AppTab>,
        isTabBarHidden: Bool
    ) -> some View {
        modifier(
            MedalCelebrationPresenterModifier(
                store: store,
                selectedTab: selectedTab,
                isTabBarHidden: isTabBarHidden
            )
        )
    }
}
