//
//  OnboardingLessonCompleteView.swift
//  ASL
//

import SwiftUI

private enum OnboardingLessonCompleteMetrics {
    static let headlineSize: CGFloat = 36
    static let subtitleSize: CGFloat = 20
    static let statValueSize: CGFloat = 38
    static let statLabelSize: CGFloat = 14
    static let statIconSize: CGFloat = 24
    static let statVerticalPadding: CGFloat = 20
    static let statCornerRadius: CGFloat = 18
    static let countUpSteps: Int = 20
    static let countUpDuration: TimeInterval = 0.85
}

struct OnboardingLessonCompleteView: View {
    let profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotIn = false
    @State private var headlineIn = false
    @State private var statsIn = false
    @State private var buttonIn = false
    @State private var confettiIn = false

    @State private var displayedSigns = 0
    @State private var displayedStars = 0
    @State private var displayedScore = 0

    @State private var countUpTask: Task<Void, Never>?

    private var signsLearned: Int { profile.miniModuleSignsLearned ?? OnboardingMiniModuleSteps.signsLearnedCount }
    private var score: Int { profile.miniModuleScore ?? 100 }
    private var starsEarned: Int { ASLStarEconomy.onboardingLessonStarAward.total }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ConfettiCanvas(palette: Brand.primary, style: .subtleStreak)
                .ignoresSafeArea()
                .opacity(confettiIn ? 1 : 0)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                OnboardingFlowProgressHeader(progress: progress)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Spacer()

                VStack(spacing: 24) {
                    Image("party")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: UnitMascot.stoneCompleteMascotMaxWidth,
                            maxHeight: UnitMascot.stoneCompleteMascotMaxHeight
                        )
                        .scaleEffect(mascotIn ? 1 : 0.85)
                        .opacity(mascotIn ? 1 : 0)

                    VStack(spacing: 10) {
                        Text(OnboardingCopy.lessonCompleteHeadline(profile: profile))
                            .font(.asl(OnboardingLessonCompleteMetrics.headlineSize, weight: .regular, design: .display))
                            .foregroundStyle(Brand.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("You completed your first lesson!")
                            .font(.asl(OnboardingLessonCompleteMetrics.subtitleSize, weight: .semibold))
                            .foregroundStyle(Brand.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .opacity(headlineIn ? 1 : 0)
                    .offset(y: headlineIn ? 0 : 12)

                    statCards
                        .opacity(statsIn ? 1 : 0)
                        .offset(y: statsIn ? 0 : 18)
                }

                Spacer()

                OnboardingPrimaryButton(title: OnboardingCopy.continueCTA, action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .opacity(buttonIn ? 1 : 0)
                    .offset(y: buttonIn ? 0 : 12)
            }
        }
        .onAppear { runCelebrationTimeline() }
        .onDisappear { countUpTask?.cancel() }
    }

    private var statCards: some View {
        HStack(spacing: 14) {
            statCard(
                icon: "leaf.fill",
                label: "Signs",
                value: "\(displayedSigns)",
                borderColor: Brand.primary
            )
            statCard(
                icon: "star.fill",
                label: "Stars",
                value: "\(displayedStars)",
                borderColor: .orange
            )
            statCard(
                icon: "bolt.fill",
                label: "Score",
                value: "\(displayedScore)%",
                borderColor: Color(red: 0.96, green: 0.54, blue: 0.20)
            )
        }
        .padding(.horizontal, 24)
    }

    private func statCard(icon: String, label: String, value: String, borderColor: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: OnboardingLessonCompleteMetrics.statIconSize, weight: .semibold))
                .foregroundStyle(borderColor)

            Text(label)
                .font(.asl(OnboardingLessonCompleteMetrics.statLabelSize, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)

            Text(value)
                .font(.asl(OnboardingLessonCompleteMetrics.statValueSize, weight: .bold, design: .ui))
                .foregroundStyle(Brand.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.12), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OnboardingLessonCompleteMetrics.statVerticalPadding)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(
                cornerRadius: OnboardingLessonCompleteMetrics.statCornerRadius,
                style: .continuous
            )
            .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: OnboardingLessonCompleteMetrics.statCornerRadius,
                style: .continuous
            )
            .strokeBorder(borderColor.opacity(0.55), lineWidth: 2.5)
        }
    }

    private func runCelebrationTimeline() {
        Haptics.stoneComplete()

        withAnimation(.easeOut(duration: 0.2)) {
            confettiIn = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            mascotIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Haptics.progressBump()
            withAnimation(.easeOut(duration: 0.32)) {
                headlineIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.easeOut(duration: 0.28)) {
                statsIn = true
            }
            startStatsCountUp()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.28)) {
                buttonIn = true
            }
        }
    }

    private func startStatsCountUp() {
        countUpTask?.cancel()
        displayedSigns = 0
        displayedStars = 0
        displayedScore = 0

        if reduceMotion {
            displayedSigns = signsLearned
            displayedStars = starsEarned
            displayedScore = score
            Haptics.progressBump()
            return
        }

        countUpTask = Task {
            await countUp(to: signsLearned) { displayedSigns = $0 }
            guard !Task.isCancelled else { return }
            Haptics.correct()

            try? await Task.sleep(for: .milliseconds(120))
            await countUp(to: starsEarned) { displayedStars = $0 }
            guard !Task.isCancelled else { return }
            Haptics.correct()

            try? await Task.sleep(for: .milliseconds(120))
            await countUp(to: score) { displayedScore = $0 }
            guard !Task.isCancelled else { return }
            Haptics.progressBump()
        }
    }

    @MainActor
    private func countUp(to target: Int, update: @escaping (Int) -> Void) async {
        guard target > 0 else {
            update(target)
            return
        }

        let steps = OnboardingLessonCompleteMetrics.countUpSteps
        let interval = OnboardingLessonCompleteMetrics.countUpDuration / Double(steps)
        var previous = 0

        for step in 1...steps {
            guard !Task.isCancelled else { return }

            let value = Int((Double(target) * Double(step) / Double(steps)).rounded(.toNearestOrAwayFromZero))
            if value != previous {
                update(value)
                if step > 1 {
                    Haptics.progressBump()
                }
                previous = value
            }

            if step < steps {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
            }
        }

        update(target)
    }
}
