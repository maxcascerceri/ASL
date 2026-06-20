//
//  DailyStreakCelebrationView.swift
//  ASL
//

import SwiftUI

enum DailyStreakCelebrationMetrics {
    static let flameRingSize: CGFloat = 180
    static let flameRingLineWidth: CGFloat = 5
    static let flameIconSize: CGFloat = 72
    static let streakNumberSize: CGFloat = 72
    static let streakLabelSize: CGFloat = 22
    static let encouragementSize: CGFloat = 20
    static let weekdayLabelSize: CGFloat = 14
    static let dayCircleSize: CGFloat = 38
    static let dayFlameIconSize: CGFloat = 16
    static let dayCheckmarkSize: CGFloat = 14
    static let weekStripVerticalPadding: CGFloat = 20
    static let weekStripHorizontalPadding: CGFloat = 16
    static let weekStripCornerRadius: CGFloat = 18
    static let weekStripBorderWidth: CGFloat = 2.5
    static let countUpSteps: Int = 20
    static let countUpDuration: TimeInterval = 0.85
}

struct DailyStreakCelebrationView: View {
    let streakStart: Int
    let streakTarget: Int
    let weekDays: [ASLDataStore.StreakDayState]
    let encouragement: String
    let showsOnboardingHeader: Bool
    var progress: Double = 0
    let continueTitle: String
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confettiIn = false
    @State private var flameIn = false
    @State private var numberIn = false
    @State private var copyIn = false
    @State private var weekStripIn = false
    @State private var todayHighlightIn = false
    @State private var buttonIn = false

    @State private var displayedStreak = 0
    @State private var countUpTask: Task<Void, Never>?

    private let streakGold = Color(red: 0.96, green: 0.74, blue: 0.26)
    private let activeDayPalette = PastelPalette.dictionaryMint

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if !reduceMotion {
                ConfettiCanvas(palette: streakGold, style: .subtleStreak)
                    .ignoresSafeArea()
                    .opacity(confettiIn ? 1 : 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                if showsOnboardingHeader {
                    OnboardingFlowProgressHeader(progress: progress)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                } else {
                    Spacer(minLength: 48)
                }

                Spacer()

                VStack(spacing: 24) {
                    flameHero
                    streakCopy
                    weekStrip
                        .padding(.horizontal, 32)
                }

                Spacer()

                OnboardingPrimaryButton(title: continueTitle, action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .opacity(buttonIn ? 1 : 0)
                    .offset(y: buttonIn ? 0 : 12)
            }
        }
        .onAppear {
            runCelebrationTimeline()
        }
        .onDisappear { countUpTask?.cancel() }
    }

    private var backgroundColor: Color {
        showsOnboardingHeader ? .white : Color(.systemBackground)
    }

    private var flameHero: some View {
        ZStack {
            Circle()
                .strokeBorder(streakGold.opacity(0.3), lineWidth: DailyStreakCelebrationMetrics.flameRingLineWidth)
                .frame(
                    width: DailyStreakCelebrationMetrics.flameRingSize,
                    height: DailyStreakCelebrationMetrics.flameRingSize
                )
                .scaleEffect(flameIn ? 1 : 0.82)

            Image(systemName: "flame.fill")
                .font(.system(size: DailyStreakCelebrationMetrics.flameIconSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(flameIn ? 1 : 0.68)
        }
        .opacity(flameIn ? 1 : 0)
    }

    private var streakCopy: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                Text("\(displayedStreak)")
                    .font(.asl(DailyStreakCelebrationMetrics.streakNumberSize, weight: .semibold, design: .ui))
                    .foregroundStyle(Brand.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: displayedStreak)
                    .scaleEffect(numberIn ? 1 : 0.88)
                    .opacity(numberIn ? 1 : 0)

                Text("day streak")
                    .font(.asl(DailyStreakCelebrationMetrics.streakLabelSize, weight: .semibold))
                    .foregroundStyle(streakGold)
            }

            Text(encouragement)
                .font(.asl(DailyStreakCelebrationMetrics.encouragementSize, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .opacity(copyIn ? 1 : 0)
        .offset(y: copyIn ? 0 : 12)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays) { day in
                VStack(spacing: 8) {
                    Text(day.weekdaySymbol)
                        .font(.asl(DailyStreakCelebrationMetrics.weekdayLabelSize, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)

                    weekDayDot(for: day)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DailyStreakCelebrationMetrics.weekStripVerticalPadding)
        .padding(.horizontal, DailyStreakCelebrationMetrics.weekStripHorizontalPadding)
        .background(
            RoundedRectangle(
                cornerRadius: DailyStreakCelebrationMetrics.weekStripCornerRadius,
                style: .continuous
            )
            .strokeBorder(streakGold, lineWidth: DailyStreakCelebrationMetrics.weekStripBorderWidth)
        )
        .opacity(weekStripIn ? 1 : 0)
        .offset(y: weekStripIn ? 0 : 18)
    }

    @ViewBuilder
    private func weekDayDot(for day: ASLDataStore.StreakDayState) -> some View {
        if day.isToday {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: DailyStreakCelebrationMetrics.dayCircleSize,
                    height: DailyStreakCelebrationMetrics.dayCircleSize
                )
                .overlay {
                    Image(systemName: "flame.fill")
                        .font(.system(
                            size: DailyStreakCelebrationMetrics.dayFlameIconSize,
                            weight: .semibold
                        ))
                        .foregroundStyle(.white)
                }
                .scaleEffect(todayHighlightIn ? 1 : 0.5)
                .opacity(todayHighlightIn ? 1 : 0)
        } else if day.isActive {
            Circle()
                .fill(activeDayPalette.fill)
                .frame(
                    width: DailyStreakCelebrationMetrics.dayCircleSize,
                    height: DailyStreakCelebrationMetrics.dayCircleSize
                )
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(
                            size: DailyStreakCelebrationMetrics.dayCheckmarkSize,
                            weight: .semibold
                        ))
                        .foregroundStyle(activeDayPalette.iconTint)
                }
                .opacity(weekStripIn ? 1 : 0)
        } else {
            Circle()
                .fill(Brand.divider.opacity(0.35))
                .frame(
                    width: DailyStreakCelebrationMetrics.dayCircleSize,
                    height: DailyStreakCelebrationMetrics.dayCircleSize
                )
                .opacity(weekStripIn ? 1 : 0)
        }
    }

    private func runCelebrationTimeline() {
        if reduceMotion {
            confettiIn = true
            flameIn = true
            numberIn = true
            displayedStreak = streakTarget
            copyIn = true
            weekStripIn = true
            todayHighlightIn = true
            buttonIn = true
            Haptics.streakMilestone()
            return
        }

        Haptics.streakMilestone()

        withAnimation(.easeOut(duration: 0.2)) {
            confettiIn = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            flameIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Haptics.progressBump()
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                numberIn = true
            }
            startStreakCountUp()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            Haptics.progressBump()
            withAnimation(.easeOut(duration: 0.32)) {
                copyIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.easeOut(duration: 0.28)) {
                weekStripIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            Haptics.correct()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                todayHighlightIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            withAnimation(.easeOut(duration: 0.28)) {
                buttonIn = true
            }
        }
    }

    private func startStreakCountUp() {
        countUpTask?.cancel()
        displayedStreak = streakStart

        guard streakTarget > streakStart else {
            displayedStreak = streakTarget
            return
        }

        countUpTask = Task {
            await countUp(from: streakStart, to: streakTarget) { displayedStreak = $0 }
            guard !Task.isCancelled else { return }
            Haptics.correct()
        }
    }

    @MainActor
    private func countUp(from start: Int, to target: Int, update: @escaping (Int) -> Void) async {
        let range = target - start
        guard range > 0 else {
            update(target)
            return
        }

        let steps = DailyStreakCelebrationMetrics.countUpSteps
        let interval = DailyStreakCelebrationMetrics.countUpDuration / Double(steps)
        var previous = start

        for step in 1...steps {
            guard !Task.isCancelled else { return }

            let value = start + Int((Double(range) * Double(step) / Double(steps)).rounded(.toNearestOrAwayFromZero))
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
