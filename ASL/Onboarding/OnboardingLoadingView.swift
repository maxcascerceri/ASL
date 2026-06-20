//
//  OnboardingLoadingView.swift
//  ASL
//

import SwiftUI

private enum OnboardingPersonalizingMetrics {
    static let headlineSize: CGFloat = 34
    static let sublineSize: CGFloat = 20
    static let cardCornerRadius: CGFloat = 22
    static let cardBorderWidth: CGFloat = 2
    static let rowFontSize: CGFloat = 19
    static let rowIconSize: CGFloat = 28
    static let rowCheckmarkSize: CGFloat = 14
    static let progressBarHeight: CGFloat = 12
    static let progressLabelSize: CGFloat = 16
    static let contentSpacing: CGFloat = 26
    static let headlineToSublineSpacing: CGFloat = 10
    static let sublineRowSpacing: CGFloat = 4
    static let sublineToCardSpacing: CGFloat = 12
    static let cardToProgressSpacing: CGFloat = 28
    static let cardHorizontalPadding: CGFloat = 24
    static let cardVerticalPadding: CGFloat = 22
    static let cardRowSpacing: CGFloat = 18
    static let horizontalPadding: CGFloat = 28
    /// Keeps the subline slot height stable when swapping to the ready message.
    static let sublineMinHeight: CGFloat = 52
    static let footerButtonHeight: CGFloat = 56 + 5
    static var stepCount: Int { OnboardingCopy.personalizingSteps.count }

    // Staged timeline
    static let screenEnterHapticDelay: TimeInterval = 0.08
    static let headlineDelay: TimeInterval = 0.15
    static let cardDelay: TimeInterval = 0.38
    static let step1CompleteDelay: TimeInterval = 1.85
    static let step2CompleteDelay: TimeInterval = 3.35
    static let step3CompleteDelay: TimeInterval = 4.85
    static let step4CompleteDelay: TimeInterval = 6.35
    static let mascotBumpDelay: TimeInterval = 6.65
}

private enum PersonalizingStepState {
    case pending
    case active
    case complete
}

struct OnboardingLoadingView: View {
    let profile: OnboardingProfile
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotIn = false
    @State private var mascotReadyBump = false
    @State private var headlineIn = false
    @State private var cardIn = false
    @State private var sublinePrimary = ""
    @State private var sublineSecondary: String?
    @State private var stepStates: [PersonalizingStepState] = Array(
        repeating: .pending,
        count: OnboardingPersonalizingMetrics.stepCount
    )
    @State private var checklistProgress: Double = 0
    @State private var progressStepLabel = 1
    @State private var isReadySubline = false
    @State private var isReadyForLesson = false
    @State private var didAdvance = false
    @State private var scheduledWork: [DispatchWorkItem] = []

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: OnboardingPersonalizingMetrics.contentSpacing) {
                personalizingMascot
                    .scaleEffect(mascotDisplayScale)
                    .opacity(mascotIn ? 1 : 0)

                VStack(spacing: OnboardingPersonalizingMetrics.headlineToSublineSpacing) {
                    Text(OnboardingCopy.personalizingHeadline)
                        .font(.asl(OnboardingPersonalizingMetrics.headlineSize, weight: .bold, design: .display))
                        .foregroundStyle(Brand.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: OnboardingPersonalizingMetrics.sublineRowSpacing) {
                        Text(sublinePrimary)
                            .font(.asl(OnboardingPersonalizingMetrics.sublineSize, weight: isReadySubline ? .bold : .semibold))
                            .foregroundStyle(isReadySubline ? Brand.textPrimary : Brand.secondaryLabel)
                            .multilineTextAlignment(.center)

                        if let sublineSecondary {
                            Text(sublineSecondary)
                                .font(.asl(OnboardingPersonalizingMetrics.sublineSize, weight: .semibold))
                                .foregroundStyle(Brand.secondaryLabel)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(
                        minHeight: OnboardingPersonalizingMetrics.sublineMinHeight,
                        alignment: .center
                    )
                }
                .padding(.horizontal, OnboardingPersonalizingMetrics.horizontalPadding)
                .opacity(headlineIn ? 1 : 0)
                .offset(y: headlineIn ? 0 : 8)

                checklistCard
                    .padding(.horizontal, OnboardingPersonalizingMetrics.horizontalPadding)
                    .padding(.top, OnboardingPersonalizingMetrics.sublineToCardSpacing)
                    .opacity(cardIn ? 1 : 0)
                    .offset(y: cardIn ? 0 : 8)

                progressSection
                    .padding(.horizontal, OnboardingPersonalizingMetrics.horizontalPadding)
                    .padding(.top, OnboardingPersonalizingMetrics.cardToProgressSpacing)
                    .opacity(cardIn ? 1 : 0)
            }

            Spacer()

            OnboardingPrimaryButton(
                title: OnboardingCopy.personalizingStartCTA,
                action: finishIfNeeded
            )
            .opacity(isReadyForLesson ? 1 : 0)
            .allowsHitTesting(isReadyForLesson)
            .animation(.easeOut(duration: 0.25), value: isReadyForLesson)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(height: OnboardingPersonalizingMetrics.footerButtonHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            let subline = OnboardingCopy.personalizingSubline(profile: profile)
            sublinePrimary = subline.primary
            sublineSecondary = subline.secondary
            runPersonalizingTimeline()
        }
        .onDisappear {
            cancelScheduledWork()
        }
    }

    private var mascotDisplayScale: CGFloat {
        if !mascotIn { return 0.94 }
        if mascotReadyBump { return 1.02 }
        return 1
    }

    private var personalizingMascot: some View {
        Image("redrill-review-teaching")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: OnboardingMascotMetrics.standaloneMascotSize,
                maxHeight: OnboardingMascotMetrics.standaloneMascotSize
            )
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: OnboardingPersonalizingMetrics.cardRowSpacing) {
            ForEach(Array(OnboardingCopy.personalizingSteps.enumerated()), id: \.offset) { index, label in
                PersonalizingStepRow(
                    label: label,
                    state: stepStates.indices.contains(index) ? stepStates[index] : .pending
                )
            }
        }
        .padding(.horizontal, OnboardingPersonalizingMetrics.cardHorizontalPadding)
        .padding(.vertical, OnboardingPersonalizingMetrics.cardVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: OnboardingPersonalizingMetrics.cardCornerRadius,
                style: .continuous
            )
            .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: OnboardingPersonalizingMetrics.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(Brand.divider, lineWidth: OnboardingPersonalizingMetrics.cardBorderWidth)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    PremiumProgressBarTrack(height: OnboardingPersonalizingMetrics.progressBarHeight)
                    PremiumProgressBarFill(
                        color: Brand.primary,
                        shadowColor: Brand.primaryShadow,
                        height: OnboardingPersonalizingMetrics.progressBarHeight
                    )
                    .frame(width: progressBarWidth(in: geo))
                    .clipShape(Capsule(style: .continuous))
                    .animation(.easeInOut(duration: 0.45), value: checklistProgress)
                }
            }
            .frame(height: OnboardingPersonalizingMetrics.progressBarHeight)

            Text("Step \(progressStepLabel) of \(OnboardingPersonalizingMetrics.stepCount)")
                .font(.asl(OnboardingPersonalizingMetrics.progressLabelSize, weight: .bold))
                .foregroundStyle(Brand.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func progressBarWidth(in geo: GeometryProxy) -> CGFloat {
        let clamped = max(0, min(1, checklistProgress))
        let width = geo.size.width * clamped
        guard width > 0 else { return 0 }
        return min(geo.size.width, max(PremiumProgressBarMetrics.minFillWidth, width))
    }

    private func runPersonalizingTimeline() {
        cancelScheduledWork()

        if reduceMotion {
            mascotIn = true
            headlineIn = true
            cardIn = true
            stepStates = Array(repeating: .complete, count: OnboardingPersonalizingMetrics.stepCount)
            checklistProgress = 1
            progressStepLabel = OnboardingPersonalizingMetrics.stepCount
            markLessonReady()
            Haptics.tap()
            Haptics.correct()
            return
        }

        schedule(after: OnboardingPersonalizingMetrics.screenEnterHapticDelay) {
            Haptics.tap()
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            mascotIn = true
        }

        schedule(after: OnboardingPersonalizingMetrics.headlineDelay) {
            withAnimation(.easeOut(duration: 0.28)) {
                headlineIn = true
            }
        }

        schedule(after: OnboardingPersonalizingMetrics.cardDelay) {
            withAnimation(.easeOut(duration: 0.28)) {
                cardIn = true
            }
            activateStep(0)
            Haptics.progressBump()
            withAnimation(.easeInOut(duration: 0.5)) {
                checklistProgress = progressFraction(forStep: 1)
            }
            progressStepLabel = 1
        }

        schedule(after: OnboardingPersonalizingMetrics.step1CompleteDelay) {
            completeStep(0)
            activateStep(1)
            Haptics.progressBump()
            withAnimation(.easeInOut(duration: 0.5)) {
                checklistProgress = progressFraction(forStep: 2)
            }
            progressStepLabel = 2
        }

        schedule(after: OnboardingPersonalizingMetrics.step2CompleteDelay) {
            completeStep(1)
            activateStep(2)
            Haptics.progressBump()
            withAnimation(.easeInOut(duration: 0.5)) {
                checklistProgress = progressFraction(forStep: 3)
            }
            progressStepLabel = 3
        }

        schedule(after: OnboardingPersonalizingMetrics.step3CompleteDelay) {
            completeStep(2)
            activateStep(3)
            Haptics.progressBump()
        }

        schedule(after: OnboardingPersonalizingMetrics.step4CompleteDelay) {
            completeStep(3)
            Haptics.correct()
            withAnimation(.easeInOut(duration: 0.5)) {
                checklistProgress = progressFraction(forStep: 4)
            }
            progressStepLabel = 4
            markLessonReady()
        }

        schedule(after: OnboardingPersonalizingMetrics.mascotBumpDelay) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                mascotReadyBump = true
            }
            schedule(after: 0.2) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    mascotReadyBump = false
                }
            }
        }

    }

    private func markLessonReady() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sublinePrimary = OnboardingCopy.personalizingReady
            sublineSecondary = nil
            isReadySubline = true
            isReadyForLesson = true
        }
    }

    private func progressFraction(forStep step: Int) -> Double {
        let total = Double(OnboardingPersonalizingMetrics.stepCount)
        return Double(step) / total
    }

    private func activateStep(_ index: Int) {
        guard stepStates.indices.contains(index) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            stepStates[index] = .active
        }
    }

    private func completeStep(_ index: Int) {
        guard stepStates.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            stepStates[index] = .complete
        }
    }

    private func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        let work = DispatchWorkItem {
            action()
        }
        scheduledWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelScheduledWork() {
        scheduledWork.forEach { $0.cancel() }
        scheduledWork.removeAll()
    }

    private func finishIfNeeded() {
        guard !didAdvance else { return }
        didAdvance = true
        cancelScheduledWork()
        onFinished()
    }
}

private struct PersonalizingStepRow: View {
    let label: String
    let state: PersonalizingStepState

    private static let checkFill = Color(red: 0.96, green: 0.74, blue: 0.26)
    private static let pendingBorder = Color(red: 0.90, green: 0.91, blue: 0.93)

    @State private var activePulse = false

    var body: some View {
        HStack(spacing: 14) {
            stepIndicator
            Text(label)
                .font(.asl(OnboardingPersonalizingMetrics.rowFontSize, weight: rowWeight))
                .foregroundStyle(labelColor)
        }
        .onChange(of: state) { _, newValue in
            activePulse = newValue == .active
        }
        .onAppear {
            activePulse = state == .active
        }
    }

    private var labelColor: Color {
        switch state {
        case .pending:
            return Brand.secondaryLabel
        case .active, .complete:
            return Brand.textPrimary
        }
    }

    private var rowWeight: Font.Weight {
        switch state {
        case .pending:
            return .semibold
        case .active, .complete:
            return .bold
        }
    }

    @ViewBuilder
    private var stepIndicator: some View {
        switch state {
        case .pending:
            Circle()
                .strokeBorder(Self.pendingBorder, lineWidth: 2)
                .frame(width: OnboardingPersonalizingMetrics.rowIconSize, height: OnboardingPersonalizingMetrics.rowIconSize)
        case .active:
            Circle()
                .strokeBorder(Brand.primary, lineWidth: 2.5)
                .frame(width: OnboardingPersonalizingMetrics.rowIconSize, height: OnboardingPersonalizingMetrics.rowIconSize)
                .opacity(activePulse ? 0.55 : 1)
                .animation(
                    activePulse
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .default,
                    value: activePulse
                )
        case .complete:
            ZStack {
                Circle()
                    .fill(Self.checkFill)
                Image(systemName: "checkmark")
                    .font(.system(size: OnboardingPersonalizingMetrics.rowCheckmarkSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: OnboardingPersonalizingMetrics.rowIconSize, height: OnboardingPersonalizingMetrics.rowIconSize)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
