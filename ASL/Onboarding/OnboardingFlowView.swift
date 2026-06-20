//
//  OnboardingFlowView.swift
//  ASL
//

import SwiftUI

struct OnboardingFlowView: View {
    let onReachPaywall: () -> Void
    let onTrialStarted: () -> Void

    @EnvironmentObject private var store: ASLDataStore

    @State private var step: OnboardingStep
    @State private var profile: OnboardingProfile
    @State private var navigationDirection: Edge = .trailing

    init(
        onReachPaywall: @escaping () -> Void,
        onTrialStarted: @escaping () -> Void
    ) {
        self.onReachPaywall = onReachPaywall
        self.onTrialStarted = onTrialStarted
        let loaded = ASLOnboarding.loadProfile()
        _profile = State(initialValue: loaded)
        _step = State(initialValue: ASLOnboarding.resumeStep(for: loaded))
    }

    var body: some View {
        stepView
            .id(step)
            .transition(onboardingStepTransition)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: step)
            .onAppear {
                warmOnboardingMedia()
                if profile.lastReachedStep == nil {
                    profile.lastReachedStep = step
                    persistProfile()
                }
            }
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .splash:
            Color.clear
                .onAppear { goTo(.welcome) }

        case .welcome:
            OnboardingWelcomeView {
                goTo(.ziggyIntro)
            }

        case .ziggyIntro:
            OnboardingZiggyIntroView {
                goTo(.motivation)
            }

        case .motivation:
            OnboardingMotivationView(
                progress: progressValue,
                selections: $profile.motivations,
                onBack: { goTo(.ziggyIntro) },
                onContinue: {
                    persistProfile()
                    goTo(.dailyGoal)
                }
            )

        case .dailyGoal:
            OnboardingDailyGoalView(
                progress: progressValue,
                selection: $profile.dailyMinutes,
                onBack: { goTo(.motivation) },
                onContinue: {
                    persistProfile()
                    goTo(.loading)
                }
            )

        case .loading:
            OnboardingLoadingView(profile: profile) {
                goTo(.miniModule)
            }

        case .miniModule:
            OnboardingMiniModuleView(store: store) { score, signsLearned in
                profile.completedMiniModule = true
                profile.miniModuleScore = score
                profile.miniModuleSignsLearned = signsLearned
                persistProfile()
                goTo(.lessonComplete)
            }

        case .lessonComplete:
            OnboardingLessonCompleteView(profile: profile, progress: progressValue) {
                goTo(.dayStreak)
            }

        case .appStoreReview:
            Color.clear
                .onAppear { goTo(.dayStreak) }

        case .dayStreak:
            OnboardingDayStreakView(progress: progressValue) {
                goTo(.streakGoal)
            }

        case .streakGoal:
            OnboardingStreakGoalView(
                progress: progressValue,
                selection: $profile.streakGoal
            ) {
                persistProfile()
                goTo(.threeMonthVision)
            }

        case .threeMonthVision:
            OnboardingVisionView(profile: profile, progress: progressValue) {
                goTo(.scienceFact)
            }

        case .scienceFact:
            OnboardingScienceFactView(profile: profile, progress: progressValue) {
                onReachPaywall()
                goTo(.paywall)
            }

        case .paywall:
            OnboardingPaywallView(
                profile: profile,
                progress: progressValue,
                onTrialStarted: onTrialStarted
            )
        }
    }

    private var onboardingStepTransition: AnyTransition {
        let insertionEdge: Edge = navigationDirection == .trailing ? .trailing : .leading
        let removalEdge: Edge = navigationDirection == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var progressValue: Double {
        OnboardingFlowProgress.fraction(for: step)
    }

    private func goTo(_ next: OnboardingStep) {
        navigationDirection = next.rawValue >= step.rawValue ? .trailing : .leading
        profile.lastReachedStep = next
        persistProfile()
        step = next
    }

    private func persistProfile() {
        ASLOnboarding.saveProfile(profile)
    }

    private func warmOnboardingMedia() {
        _ = BundledPlaybackCache.ensureCached(wordId: "welcome")
        for wordId in OnboardingMiniModuleSteps.warmupWordIds {
            _ = BundledPlaybackCache.ensureCached(wordId: wordId)
        }
    }
}
