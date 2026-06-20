//
//  DailyStreakCelebrationPresenter.swift
//  ASL
//

import SwiftUI

private struct DailyStreakCelebrationPresenterModifier: ViewModifier {
    @ObservedObject var store: ASLDataStore
    let isTabBarHidden: Bool

    @State private var presentedCelebration: DailyStreakCelebrationPayload?
    @State private var deferredSettleWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presentedCelebration) { payload in
                DailyStreakCelebrationView(
                    streakStart: payload.previousStreak,
                    streakTarget: payload.newStreak,
                    weekDays: store.streakWeekdayStates(),
                    encouragement: DailyStreakCelebrationCopy.encouragement(
                        newStreak: payload.newStreak,
                        continued: payload.newStreak > 1 && payload.previousStreak > 0
                    ),
                    showsOnboardingHeader: false,
                    continueTitle: "Continue",
                    onContinue: dismissCelebration
                )
            }
            .onChange(of: store.pendingDailyStreakCelebration?.dayKey) { _, _ in
                presentIfEligible()
            }
            .onChange(of: isTabBarHidden) { _, _ in
                presentIfEligible()
            }
            .onChange(of: store.isLessonMediaSessionActive) { _, _ in
                presentIfEligible()
            }
            .onChange(of: store.isPracticeSessionCompleteVisible) { _, _ in
                presentIfEligible()
            }
            .onChange(of: store.homeUnitFlowBlocksMedalCelebrations) { _, _ in
                presentIfEligible()
            }
            .onAppear {
                presentIfEligible()
            }
    }

    private func presentIfEligible() {
        deferredSettleWorkItem?.cancel()
        deferredSettleWorkItem = nil

        guard store.pendingDailyStreakCelebration != nil else { return }
        guard presentedCelebration == nil else { return }
        guard canPresentNow else {
            let work = DispatchWorkItem {
                guard canPresentNow, presentedCelebration == nil else { return }
                showCelebration()
            }
            deferredSettleWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            return
        }

        showCelebration()
    }

    private var canPresentNow: Bool {
        store.pendingDailyStreakCelebration != nil
            && presentedCelebration == nil
            && !isTabBarHidden
            && !store.isLessonMediaSessionActive
            && !store.isPracticeSessionCompleteVisible
            && !store.homeUnitFlowBlocksMedalCelebrations
    }

    private func showCelebration() {
        guard let payload = store.pendingDailyStreakCelebration else { return }
        presentedCelebration = payload
    }

    private func dismissCelebration() {
        presentedCelebration = nil
        store.clearPendingDailyStreakCelebration()
    }
}

extension View {
    func dailyStreakCelebrationPresenter(
        store: ASLDataStore,
        isTabBarHidden: Bool
    ) -> some View {
        modifier(
            DailyStreakCelebrationPresenterModifier(
                store: store,
                isTabBarHidden: isTabBarHidden
            )
        )
    }
}
