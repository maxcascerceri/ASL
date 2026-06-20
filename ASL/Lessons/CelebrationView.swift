//
//  CelebrationView.swift
//  ASL
//
//  Two celebrations:
//
//  * `StoneCelebration` - legacy small per-stone modal (superseded by
//    `ModuleCompleteCelebration` for stone completion).
//
//  * `ModuleCompleteCelebration` - full-screen stone completion overlay. Large
//    celebration mascot hero, checkmark badge, rotating headline pool, stars chip,
//    session stats, and Continue CTA (same layout rhythm as `RedrillIntroView`).
//
//  * `UnitCelebration`  - end-of-unit overlay. Unit mascot hero, staged timeline,
//    hero star count, session stats, and Continue CTA (same rhythm as stone complete).
//
//  * `StreakCelebration` - half-page bottom sheet at 5 / 10 / 20 / 40 in a row.
//    White panel, subtle confetti, streak mascot hero, and auto-dismiss after ~3.6s.
//
//  * `RedrillIntroView` - full-screen review intro shown between the initial
//    module pass and the redrill phase when the user missed one or more signs.
//    Rotating review mascots, correction icon, encouraging copy, and Continue CTA.
//
//  * `ReviewModeLabel` - compact review badge shown above lesson content during
//    the redrill phase so learners know they are replaying missed questions.
//
//  All celebrations are presented full-screen by the gameplay views via a
//  ZStack so the underlying lesson chrome stays mounted.
//

import SwiftUI

// MARK: - Star award breakdown

struct StarAwardBreakdownView: View {
    let award: StoneCompletionAward
    var style: Style = .chip

    enum Style {
        case chip
        case detailed
        case heroTotal
    }

    var body: some View {
        switch style {
        case .chip:
            starsChip(text: "+\(award.total) stars")
        case .detailed:
            VStack(spacing: 8) {
                if award.stone > 0 {
                    breakdownRow(label: "Stone complete", amount: award.stone)
                }
                if award.perfectBonus > 0 {
                    breakdownRow(label: "Perfect pass", amount: award.perfectBonus)
                }
                if award.unitGateway > 0 {
                    breakdownRow(label: "Unit complete", amount: award.unitGateway)
                }
                if award.unitMilestone > 0 {
                    breakdownRow(label: "Milestone bonus", amount: award.unitMilestone)
                }
                starsChip(text: "+\(award.total) stars")
            }
        case .heroTotal:
            EmptyView()
        }
    }

    private func breakdownRow(label: String, amount: Int) -> some View {
        HStack {
            Text(label)
                .font(.asl(14, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
            Spacer()
            Text("+\(amount)")
                .font(.asl(14, weight: .semibold))
                .foregroundStyle(Color.lessonGreen)
        }
        .padding(.horizontal, 4)
    }

    private func starsChip(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.asl(13, weight: .semibold))
            Text(text)
                .font(.asl(15, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.lessonGreen.opacity(0.18)))
        .foregroundStyle(Color.lessonGreen)
    }
}

// MARK: - Shared celebration components

struct CelebrationStatPill: View {
    let symbol: String
    let value: String
    let label: String
    let palette: Color
    var usesPaletteTint = false

    private var iconSize: CGFloat { 26 }
    private var valueSize: CGFloat { 30 }
    private var labelSize: CGFloat { 15 }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.asl(iconSize, weight: .semibold))
                .foregroundStyle(palette)

            Text(value)
                .font(.asl(valueSize, weight: .bold))
                .foregroundStyle(usesPaletteTint ? palette : Brand.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.asl(labelSize, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    usesPaletteTint
                        ? palette.opacity(0.10)
                        : Color(.secondarySystemBackground)
                )
        )
    }
}

/// Mascot hero with a sharp center and only the outer rim softened into white backgrounds.
struct CelebrationMascotHero: View {
    let imageName: String
    var maxWidth: CGFloat = UnitMascot.streakCelebrationMascotMaxWidth
    var maxHeight: CGFloat = UnitMascot.streakCelebrationMascotMaxHeight
    var contentScale: CGFloat = 1
    var applyEdgeFeather: Bool = true

    private let edgeBlurRadius: CGFloat = 5
    private let edgeFeatherFraction: CGFloat = 0.08

    var body: some View {
        Group {
            if applyEdgeFeather {
                featheredImage
            } else {
                plainImage
            }
        }
    }

    private var plainImage: some View {
        Image(imageName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .scaleEffect(contentScale)
    }

    private var featheredImage: some View {
        plainImage
            .overlay {
                Image(imageName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .scaleEffect(contentScale)
                    .blur(radius: edgeBlurRadius, opaque: false)
                    .mask { edgeRingMask }
                    .allowsHitTesting(false)
            }
            .overlay {
                edgeWhiteFeather
                    .allowsHitTesting(false)
            }
    }

    private var edgeRingMask: some View {
        Rectangle()
            .fill(.white)
            .mask(horizontalEdgeRingMask)
            .mask(verticalEdgeRingMask)
    }

    private var horizontalEdgeRingMask: LinearGradient {
        let feather = edgeFeatherFraction
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .clear, location: feather),
                .init(color: .clear, location: 1 - feather),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var verticalEdgeRingMask: LinearGradient {
        let feather = edgeFeatherFraction
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .clear, location: feather),
                .init(color: .clear, location: 1 - feather),
                .init(color: .white, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var edgeWhiteFeather: some View {
        GeometryReader { proxy in
            let horizontalFeather = min(24, proxy.size.width * edgeFeatherFraction)
            let verticalFeather = min(20, proxy.size.height * edgeFeatherFraction)

            ZStack {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: horizontalFeather)

                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: horizontalFeather)
                }

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: verticalFeather)

                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: verticalFeather)
                }
            }
        }
    }
}

// MARK: - Unit celebration shared UI

private struct StarTrophyChip: View {
    let displayedTotal: Int

    private static let streakYellow = Brand.dictionaryYellowIcon

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.asl(15, weight: .semibold))
            Text("+\(displayedTotal) stars")
                .font(.asl(16, weight: .semibold))
        }
        .foregroundStyle(Self.streakYellow)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Self.streakYellow.opacity(0.18)))
    }
}

struct UnitCelebrationFooter: View {
    let nextUnit: ASLUnit?
    let completedPalette: Color
    let completedPaletteShadow: Color
    let nextUnitPalette: Color
    let nextUnitPaletteShadow: Color
    let isVisible: Bool
    let onContinue: () -> Void

    var body: some View {
        Group {
            if let nextUnit {
                PressableRaisedUnitButton(
                    title: ASLUnitCompleteCopy.startCTA(nextUnit: nextUnit),
                    color: nextUnitPalette,
                    depthColor: nextUnitPaletteShadow,
                    action: onContinue
                )
            } else {
                PressableRaisedUnitButton(
                    title: ASLUnitCompleteCopy.continueCTA,
                    color: completedPalette,
                    depthColor: completedPaletteShadow,
                    action: onContinue
                )
            }
        }
        .padding(.horizontal, LessonActionTrayLayout.horizontalPadding)
        .padding(.bottom, LessonActionTrayLayout.effectiveBottomPadding)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 14)
    }
}

// MARK: - Stone celebration

struct StoneCelebration: View {
    let palette: Color
    let paletteShadow: Color
    let starsAwarded: Int
    let onContinue: () -> Void

    @State private var visible = false
    @State private var headline: String = StoneCelebration.headlines.randomElement() ?? "Nice!"
    @State private var autoFire: DispatchWorkItem?

    private static let headlines: [String] = [
        "Nice!",
        "Great job!",
        "You got it!",
        "On a roll!",
        "Smooth!",
        "Strong!",
        "Locked in!",
        "Boom!",
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.28 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: visible)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(palette.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(palette)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.asl(36, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(headline)
                    .font(.asl(26, weight: .regular, design: .display))
                    .foregroundStyle(Brand.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.asl(13, weight: .semibold))
                    Text("+\(starsAwarded) stars")
                        .font(.asl(15, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.lessonGreen.opacity(0.18)))
                .foregroundStyle(Color.lessonGreen)

                PressableRaisedUnitButton(
                    title: "Continue",
                    color: palette,
                    depthColor: paletteShadow,
                    height: 52,
                    depth: PremiumCardMetrics.depth,
                    action: continueNow
                )
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            )
            .padding(.horizontal, 28)
            .offset(y: visible ? 0 : 60)
            .opacity(visible ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: visible)
        }
        .onAppear {
            visible = true
            Haptics.stoneComplete()
            LessonSounds.play(.stoneComplete)
            let work = DispatchWorkItem { continueNow() }
            autoFire = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
        }
        .onDisappear { autoFire?.cancel() }
    }

    private func continueNow() {
        autoFire?.cancel()
        withAnimation(.easeIn(duration: 0.18)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: onContinue)
    }
}

// MARK: - Unit celebration

struct UnitCelebration: View {
    let unit: ASLUnit
    let palette: Color
    let paletteShadow: Color
    let starAward: StoneCompletionAward
    let bestStreak: Int
    let signsInUnit: Int
    let nextUnit: ASLUnit?
    let nextUnitPalette: Color
    let nextUnitPaletteShadow: Color
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confettiIn = false
    @State private var mascotIn = false
    @State private var headlineIn = false
    @State private var subheadIn = false
    @State private var starsIn = false
    @State private var statsIn = false
    @State private var footerIn = false
    @State private var displayedStars = 0
    @State private var countUpTask: Task<Void, Never>?

    private var badgeText: String {
        unit.badge.isEmpty ? "Unit Complete" : unit.badge
    }

    private var mascotImageName: String? {
        UnitMascot.imageName(for: unit)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if !reduceMotion {
                ConfettiCanvas(palette: palette)
                    .ignoresSafeArea()
                    .opacity(confettiIn ? 1 : 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                mascotHeroStack
                    .scaleEffect(mascotIn ? 1 : 0.88)
                    .opacity(mascotIn ? 1 : 0)

                VStack(spacing: 16) {
                    Text(ASLUnitCompleteCopy.headline(unit: unit))
                        .font(.asl(28, weight: .regular, design: .display))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 12)

                    badgePill
                        .opacity(subheadIn ? 1 : 0)
                        .offset(y: subheadIn ? 0 : 8)

                    if starAward.total > 0 {
                        StarTrophyChip(displayedTotal: displayedStars)
                            .opacity(starsIn ? 1 : 0)
                            .scaleEffect(starsIn ? 1 : 0.88)
                    }

                    statsRow
                        .opacity(statsIn ? 1 : 0)
                        .offset(y: statsIn ? 0 : 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer(minLength: 12)

                UnitCelebrationFooter(
                    nextUnit: nextUnit,
                    completedPalette: palette,
                    completedPaletteShadow: paletteShadow,
                    nextUnitPalette: nextUnitPalette,
                    nextUnitPaletteShadow: nextUnitPaletteShadow,
                    isVisible: footerIn,
                    onContinue: onContinue
                )
            }
        }
        .onAppear { runTimeline() }
        .onDisappear { countUpTask?.cancel() }
    }

    private var mascotHeroStack: some View {
        ZStack {
            Circle()
                .fill(palette.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .scaleEffect(mascotIn ? 1 : 0.85)
                .opacity(mascotIn ? 1 : 0)

            Group {
                if let mascotImageName {
                    CelebrationMascotHero(
                        imageName: mascotImageName,
                        maxWidth: UnitMascot.unitCompleteMascotMaxWidth,
                        maxHeight: UnitMascot.unitCompleteMascotMaxHeight,
                        contentScale: UnitMascot.homePathContentScale(for: mascotImageName),
                        applyEdgeFeather: false
                    )
                } else {
                    reviewFallbackHero
                }
            }
            .subtleVerticalBob(amplitude: 3)
        }
    }

    private var reviewFallbackHero: some View {
        ZStack {
            Circle()
                .fill(palette.opacity(0.18))
                .frame(width: 180, height: 180)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.opacity(0.95), palette],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 140)
            Image(systemName: "flag.checkered.2.crossed")
                .font(.asl(58, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var badgePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "rosette")
                .font(.asl(14, weight: .semibold))
            Text(badgeText)
                .font(.asl(15, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.opacity(0.18)))
        .foregroundStyle(palette)
    }

    private var statsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            CelebrationStatPill(
                symbol: "hand.wave.fill",
                value: "\(signsInUnit)",
                label: "Signs in unit",
                palette: palette
            )
            CelebrationStatPill(
                symbol: "flame.fill",
                value: "\(max(bestStreak, 0))",
                label: "Best streak",
                palette: palette
            )
        }
    }

    private func runTimeline() {
        Haptics.unitComplete()
        LessonSounds.play(.unitComplete)

        if reduceMotion {
            confettiIn = true
            mascotIn = true
            headlineIn = true
            subheadIn = true
            starsIn = true
            statsIn = true
            footerIn = true
            displayedStars = starAward.total
            return
        }

        withAnimation(.easeOut(duration: 0.15)) { confettiIn = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { mascotIn = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeOut(duration: 0.28)) { headlineIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.28)) { subheadIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { starsIn = true }
            startStarCountUp()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.28)) { statsIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.28)) { footerIn = true }
            Haptics.progressBump()
        }
    }

    private func startStarCountUp() {
        countUpTask?.cancel()
        displayedStars = 0
        let target = starAward.total
        guard target > 0 else { return }

        countUpTask = Task {
            let steps = 20
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(40))
                let value = Int((Double(target) * Double(step) / Double(steps)).rounded())
                await MainActor.run {
                    displayedStars = value
                    if step % 4 == 0 {
                        Haptics.correct()
                    }
                }
            }
            await MainActor.run {
                displayedStars = target
                Haptics.progressBump()
            }
        }
    }
}

// MARK: - Module complete celebration

struct ModuleCompleteCelebration: View {
    let palette: Color
    let paletteShadow: Color
    let starAward: StoneCompletionAward
    let correctCount: Int
    let totalCount: Int
    let bestStreak: Int
    let continueTitle: String
    let onContinue: () -> Void

    @State private var confettiIn = false
    @State private var mascotIn = false
    @State private var contentIn = false
    @State private var buttonIn = false
    @State private var headlineIndex = ASLModuleCompleteCopy.randomHeadlineIndex()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ConfettiCanvas(palette: palette, style: .subtleStreak)
                .ignoresSafeArea()
                .opacity(confettiIn ? 1 : 0)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                mascotHero
                    .scaleEffect(mascotIn ? 1 : 0.9)
                    .opacity(mascotIn ? 1 : 0)

                VStack(spacing: 16) {
                    successIcon

                    VStack(spacing: 12) {
                        Text(ASLModuleCompleteCopy.headline(index: headlineIndex))
                            .font(.asl(28, weight: .regular, design: .display))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(ASLModuleCompleteCopy.subtitle)
                            .font(.asl(17, weight: .semibold))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    StarAwardBreakdownView(award: starAward, style: .chip)

                    statsRow
                }
                .padding(.horizontal, 24)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? -34 : -10)

                Spacer()

                PressableRaisedUnitButton(
                    title: continueTitle,
                    color: palette,
                    depthColor: paletteShadow,
                    action: onContinue
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 14)
            }
        }
        .onAppear { runTimeline() }
    }

    private var mascotHero: some View {
        Image(UnitMascot.stoneCompleteCelebrationImageName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: UnitMascot.stoneCompleteMascotMaxWidth,
                maxHeight: UnitMascot.stoneCompleteMascotMaxHeight
            )
    }

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.opacity(0.95), palette],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: 52)
            Image(systemName: "checkmark")
                .font(.asl(22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var statsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            CelebrationStatPill(
                symbol: "checkmark.circle.fill",
                value: "\(correctCount)/\(totalCount)",
                label: "Correct",
                palette: palette
            )
            CelebrationStatPill(
                symbol: "flame.fill",
                value: "\(max(bestStreak, 0))",
                label: "Best streak",
                palette: palette
            )
        }
    }

    private func runTimeline() {
        Haptics.stoneComplete()
        LessonSounds.play(.stoneComplete)
        withAnimation(.easeOut(duration: 0.15)) { confettiIn = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            mascotIn = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.28)) { contentIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.28)) { buttonIn = true }
        }
    }
}

// MARK: - Streak celebration

struct StreakCelebration: View {
    let streak: Int
    let palette: Color
    let paletteShadow: Color
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheetIn = false
    @State private var confettiIn = false
    @State private var contentIn = false
    @State private var buttonIn = false
    @State private var autoFire: DispatchWorkItem?

    private static let sheetCornerRadius: CGFloat = 24
    private static let sheetHeightRatio: CGFloat = 0.63

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.tap()
                    continueNow()
                }

            GeometryReader { proxy in
                let sheetHeight = proxy.size.height * Self.sheetHeightRatio

                VStack(spacing: 0) {
                    sheetHandle

                    ZStack {
                        if !reduceMotion {
                            ConfettiCanvas(palette: palette, style: .subtleStreak)
                                .opacity(confettiIn ? 1 : 0)
                                .allowsHitTesting(false)
                        }

                        VStack(spacing: 0) {
                            Spacer(minLength: 20)

                            mascot
                                .layoutPriority(1)
                                .scaleEffect(contentIn ? 1.0 : 0.92)
                                .opacity(contentIn ? 1 : 0)

                            Text(ASLStreakCelebrationCopy.headline(streak: streak))
                                .font(.asl(24, weight: .regular, design: .display))
                                .foregroundStyle(Brand.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
                                .opacity(contentIn ? 1 : 0)
                                .offset(y: contentIn ? 0 : 6)

                            PressableLessonPrimaryButton(
                                title: "Continue",
                                color: palette,
                                depthColor: paletteShadow,
                                action: continueNow
                            )
                            .padding(.horizontal, LessonActionTrayLayout.horizontalPadding)
                            .padding(.top, 28)
                            .padding(.bottom, LessonActionTrayLayout.effectiveBottomPadding)
                            .opacity(buttonIn ? 1 : 0)
                            .offset(y: buttonIn ? 0 : 12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: sheetHeight)
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Self.sheetCornerRadius,
                        topTrailingRadius: Self.sheetCornerRadius
                    )
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
                )
                .offset(y: sheetIn ? 0 : sheetHeight + 24)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { runTimeline() }
        .onDisappear { autoFire?.cancel() }
    }

    private var sheetHandle: some View {
        Capsule()
            .fill(Brand.divider)
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var mascot: some View {
        CelebrationMascotHero(
            imageName: UnitMascot.streakCelebrationImageName(for: streak),
            maxWidth: UnitMascot.streakCelebrationMascotMaxWidth,
            maxHeight: UnitMascot.streakCelebrationMascotMaxHeight
        )
    }

    private func runTimeline() {
        if reduceMotion {
            sheetIn = true
            contentIn = true
            buttonIn = true
            Haptics.streakMilestone()
            scheduleAutoDismiss()
            return
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            sheetIn = true
        }
        withAnimation(.easeOut(duration: 0.15)) { confettiIn = true }
        Haptics.streakMilestone()
        LessonSounds.play(.correct)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                contentIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeOut(duration: 0.22)) { buttonIn = true }
        }

        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        let work = DispatchWorkItem { continueNow() }
        autoFire = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6, execute: work)
    }

    private func continueNow() {
        autoFire?.cancel()
        autoFire = nil
        if reduceMotion {
            onContinue()
            return
        }
        withAnimation(.easeIn(duration: 0.2)) { sheetIn = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: onContinue)
    }
}

// MARK: - Redrill intro

struct RedrillIntroView: View {
    let palette: Color
    let paletteShadow: Color
    let onStart: () -> Void

    @State private var mascotImageName: String?
    @State private var mascotIn = false
    @State private var contentIn = false
    @State private var buttonIn = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                mascotHero
                    .scaleEffect(mascotIn ? 1 : 0.9)
                    .opacity(mascotIn ? 1 : 0)

                VStack(spacing: 16) {
                    correctionIcon

                    VStack(spacing: 12) {
                        Text(ASLRedrillCopy.introHeadline)
                            .font(.asl(32, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(ASLRedrillCopy.introSubtitle)
                            .font(.asl(17, weight: .semibold))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 24)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? -22 : -6)

                Spacer()

                PressableRaisedUnitButton(
                    title: ASLRedrillCopy.introCTA,
                    color: palette,
                    depthColor: paletteShadow,
                    action: onStart
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 14)
            }
        }
        .onAppear {
            mascotImageName = UnitMascot.nextReviewIntroMascotImageName()
            runTimeline()
        }
    }

    @ViewBuilder
    private var mascotHero: some View {
        if let mascotImageName {
            Image(mascotImageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: UnitMascot.reviewIntroMascotMaxWidth,
                    maxHeight: UnitMascot.reviewIntroMascotMaxHeight
                )
        } else {
            Color.clear
                .frame(
                    width: UnitMascot.reviewIntroMascotMaxWidth,
                    height: UnitMascot.reviewIntroMascotMaxHeight
                )
        }
    }

    private var correctionIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.opacity(0.95), palette],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: 52)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.asl(22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func runTimeline() {
        Haptics.progressBump()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            mascotIn = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.28)) { contentIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.28)) { buttonIn = true }
        }
    }
}

// MARK: - Review mode label

struct ReviewModeLabel: View {
    let palette: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(palette)
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.asl(17, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(ASLRedrillCopy.reviewLabel)
                .font(.asl(19, weight: .semibold))
                .foregroundStyle(palette)
                .tracking(0.4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Review mode")
    }
}

// MARK: - Phase review intro

struct PhaseReviewIntroView: View {
    let phaseTitle: String
    let phaseKey: String?
    let palette: Color
    let paletteShadow: Color
    let onStart: () -> Void

    @State private var symbolIn = false
    @State private var headlineIn = false
    @State private var subheadIn = false
    @State private var roundsIn = false
    @State private var buttonIn = false
    @State private var symbolPulse = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                ZStack {
                    Circle()
                        .fill(palette.opacity(0.18))
                        .frame(width: 180, height: 180)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.opacity(0.95), palette],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 150, height: 150)
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.asl(58, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(symbolPulse ? 1.06 : 0.94)
                }
                .scaleEffect(symbolIn ? 1.0 : 0.78)
                .opacity(symbolIn ? 1 : 0)

                Spacer(minLength: 22)

                VStack(spacing: 12) {
                    Text(ASLPhaseReviewCopy.introHeadline(for: phaseKey))
                        .aslStyle(.celebrationHeadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 12)

                    Text(ASLPhaseReviewCopy.introSubtitle(phaseTitle: phaseTitle))
                        .aslStyle(.cardDescription, variant: .prominent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(subheadIn ? 1 : 0)
                }

                Spacer(minLength: 20)

                HStack(spacing: 10) {
                    ForEach(Array(PhaseReviewRound.allCases.enumerated()), id: \.offset) { index, round in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.asl(12, weight: .medium))
                                .foregroundStyle(Brand.secondaryLabel.opacity(0.55))
                        }
                        roundPreview(round)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(roundsIn ? 1 : 0)
                .offset(y: roundsIn ? 0 : 10)

                Spacer(minLength: 24)

                PressableRaisedUnitButton(
                    title: "Begin checkpoint",
                    color: palette,
                    depthColor: paletteShadow,
                    action: onStart
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 18)
            }
        }
        .onAppear { runTimeline() }
    }

    private func roundPreview(_ round: PhaseReviewRound) -> some View {
        VStack(spacing: 6) {
            Image(systemName: round.icon)
                .font(.asl(18, weight: .semibold))
                .foregroundStyle(palette)
                .frame(width: 40, height: 40)
                .background(palette.opacity(0.14), in: Circle())
            Text(round.shortTitle)
                .font(.asl(12, weight: .medium))
                .foregroundStyle(Brand.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func runTimeline() {
        Haptics.progressBump()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.64)) {
                symbolIn = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                symbolPulse = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.easeOut(duration: 0.32)) { headlineIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.30)) { subheadIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.easeOut(duration: 0.30)) { roundsIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.28)) { buttonIn = true }
        }
    }
}

// MARK: - Phase review complete

struct PhaseReviewCompleteCelebration: View {
    let palette: Color
    let paletteShadow: Color
    let phaseTitle: String
    let phaseKey: String
    let starAward: StoneCompletionAward
    let correctCount: Int
    let totalCount: Int
    let bestStreak: Int
    let nextUnit: ASLUnit?
    let nextUnitPalette: Color
    let nextUnitPaletteShadow: Color
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confettiIn = false
    @State private var mascotIn = false
    @State private var headlineIn = false
    @State private var subheadIn = false
    @State private var starsIn = false
    @State private var statsIn = false
    @State private var footerIn = false
    @State private var displayedStars = 0
    @State private var countUpTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if !reduceMotion {
                ConfettiCanvas(palette: palette)
                    .ignoresSafeArea()
                    .opacity(confettiIn ? 1 : 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                mascotHeroStack
                    .scaleEffect(mascotIn ? 1 : 0.88)
                    .opacity(mascotIn ? 1 : 0)

                VStack(spacing: 16) {
                    Text(ASLPhaseReviewCopy.completionHeadline(phaseTitle: phaseTitle))
                        .font(.asl(28, weight: .regular, design: .display))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 12)

                    Text(ASLPhaseReviewCopy.skillsSummary(phaseKey: phaseKey, phaseTitle: phaseTitle))
                        .font(.asl(16, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 8)
                        .opacity(subheadIn ? 1 : 0)

                    if starAward.total > 0 {
                        StarTrophyChip(displayedTotal: displayedStars)
                            .opacity(starsIn ? 1 : 0)
                            .scaleEffect(starsIn ? 1 : 0.88)
                    }

                    statsRow
                        .opacity(statsIn ? 1 : 0)
                        .offset(y: statsIn ? 0 : 10)

                    if starAward.unitGateway > 0 || starAward.unitMilestone > 0 || starAward.perfectBonus > 0 {
                        StarAwardBreakdownView(award: starAward, style: .detailed)
                            .opacity(statsIn ? 1 : 0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer(minLength: 12)

                UnitCelebrationFooter(
                    nextUnit: nextUnit,
                    completedPalette: palette,
                    completedPaletteShadow: paletteShadow,
                    nextUnitPalette: nextUnitPalette,
                    nextUnitPaletteShadow: nextUnitPaletteShadow,
                    isVisible: footerIn,
                    onContinue: onContinue
                )
            }
        }
        .onAppear { runTimeline() }
        .onDisappear { countUpTask?.cancel() }
    }

    private var mascotHeroStack: some View {
        ZStack {
            Circle()
                .fill(palette.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .scaleEffect(mascotIn ? 1 : 0.85)
                .opacity(mascotIn ? 1 : 0)

            Image("SignMascot")
                .resizable()
                .scaledToFit()
                .frame(height: UnitMascot.celebrationMascotHeight)
                .subtleVerticalBob(amplitude: 3)
        }
    }

    private var statsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            CelebrationStatPill(
                symbol: "checkmark.circle.fill",
                value: "\(correctCount)/\(totalCount)",
                label: "Correct",
                palette: palette,
                usesPaletteTint: true
            )
            CelebrationStatPill(
                symbol: "flame.fill",
                value: "\(max(bestStreak, 0))",
                label: "Best streak",
                palette: palette,
                usesPaletteTint: true
            )
        }
    }

    private func runTimeline() {
        Haptics.unitComplete()
        LessonSounds.play(.unitComplete)

        if reduceMotion {
            confettiIn = true
            mascotIn = true
            headlineIn = true
            subheadIn = true
            starsIn = true
            statsIn = true
            footerIn = true
            displayedStars = starAward.total
            return
        }

        withAnimation(.easeOut(duration: 0.15)) { confettiIn = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { mascotIn = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeOut(duration: 0.28)) { headlineIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.28)) { subheadIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { starsIn = true }
            startStarCountUp()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.28)) { statsIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.28)) { footerIn = true }
            Haptics.progressBump()
        }
    }

    private func startStarCountUp() {
        countUpTask?.cancel()
        displayedStars = 0
        let target = starAward.total
        guard target > 0 else { return }

        countUpTask = Task {
            let steps = 20
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(40))
                let value = Int((Double(target) * Double(step) / Double(steps)).rounded())
                await MainActor.run {
                    displayedStars = value
                    if step % 4 == 0 {
                        Haptics.correct()
                    }
                }
            }
            await MainActor.run {
                displayedStars = target
                Haptics.progressBump()
            }
        }
    }
}

// MARK: - Confetti

enum ConfettiStyle {
    /// Full-screen falling confetti for unit, module, and medal celebrations.
    case celebration
    /// Quieter top-weighted burst for in-lesson streak milestones.
    case subtleStreak
}

struct ConfettiCanvas: View {
    let palette: Color
    var style: ConfettiStyle = .celebration

    /// Higher = slower, more elegant fall.
    private let duration: Double = 2.4

    private var particleCount: Int {
        switch style {
        case .celebration: return 55
        case .subtleStreak: return 24
        }
    }

    private var recycles: Bool {
        switch style {
        case .celebration: return true
        case .subtleStreak: return false
        }
    }

    private var maxVerticalFraction: CGFloat {
        switch style {
        case .celebration: return 1.0
        case .subtleStreak: return 0.4
        }
    }

    private var particles: [Particle] {
        (0..<particleCount).map { i in
            Particle(
                seed: i,
                horizontal: seededUnit(i, salt: 1),
                rotationSpeed: seededUnit(i, salt: 2) * 4 - 2,
                colorMix: seededUnit(i, salt: 3),
                driftAmplitude: 10 + seededUnit(i, salt: 4) * 12,
                opacity: style == .subtleStreak
                    ? 0.35 + seededUnit(i, salt: 5) * 0.30
                    : 1.0
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let maxY = size.height * maxVerticalFraction
                for particle in particles {
                    let progress = particle.progress(
                        at: t,
                        duration: duration,
                        recycles: recycles
                    )
                    guard progress < 1 else { continue }

                    let drift = sin(progress * .pi * 3) * particle.driftAmplitude
                    let x = particle.horizontal * size.width + drift
                    let fallDistance = maxY + 80
                    let y = -20 + progress * fallDistance
                    guard y <= maxY + 20 else { continue }
                    let angle = Angle(radians: progress * .pi * 2 * particle.rotationSpeed)

                    var transform = CGAffineTransform(translationX: x, y: y)
                    transform = transform.rotated(by: angle.radians)

                    let rect = CGRect(x: -4, y: -8, width: 8, height: 14)
                    let path = Path(roundedRect: rect, cornerRadius: 2).applying(transform)
                    ctx.fill(
                        path,
                        with: .color(particleColor(particle.colorMix).opacity(particle.opacity))
                    )
                }
            }
        }
    }

    private func seededUnit(_ seed: Int, salt: Int) -> Double {
        var hash = UInt64(seed &+ 1) &* 1_099_511_628_289 &+ UInt64(salt &* 97)
        hash ^= hash >> 33
        hash &*= 1_839_760_515_439_344_137
        hash ^= hash >> 29
        return Double(hash % 10_000) / 9_999.0
    }

    private func particleColor(_ mix: Double) -> Color {
        switch style {
        case .celebration:
            if mix < 0.33 { return palette }
            if mix < 0.66 { return Color.lessonGreen }
            return Color.yellow
        case .subtleStreak:
            if mix < 0.5 { return palette }
            if mix < 0.8 { return Brand.soft }
            return palette.opacity(0.6)
        }
    }

    private struct Particle: Identifiable {
        let id = UUID()
        let seed: Int
        let horizontal: Double
        let rotationSpeed: Double
        let colorMix: Double
        let driftAmplitude: Double
        let opacity: Double

        func progress(at time: Double, duration: Double, recycles: Bool) -> Double {
            let offset = Double(seed) * 0.08
            let local = time - offset
            if recycles {
                let cycled = local.truncatingRemainder(dividingBy: duration + 3)
                return max(0, min(1, cycled / duration))
            }
            guard local >= 0 else { return 0 }
            return max(0, min(1, local / duration))
        }
    }
}
