//
//  PracticeSessionCompleteView.swift
//  ASL
//

import SwiftUI

enum ASLPracticeCompleteCopy {
    private static let headlines = [
        "You crushed it!",
        "Nice work!",
        "Practice complete!",
        "Locked in!",
        "On a roll!",
        "Great job!",
    ]

    static let continueCTA = "Continue"

    static func headline(for mode: PracticeMode, index: Int) -> String {
        if mode == .spellYourName {
            return "Nice — that's a real introduction skill."
        }
        return rotatedHeadline(index: index)
    }

    private static func rotatedHeadline(index: Int) -> String {
        guard !headlines.isEmpty else { return "Nice work!" }
        return headlines[index % headlines.count]
    }

    static func randomHeadlineIndex() -> Int {
        Int.random(in: 0..<headlines.count)
    }

    static func subtitle(for mode: PracticeMode) -> String {
        switch mode {
        case .quiz:
            return "Quiz done. Keep building your fluency!"
        case .flashcards:
            return "Cards reviewed. Nice repetition!"
        case .spellYourName:
            return "You can fingerspell your name now — try it in your next conversation."
        case .vocabularyMatch:
            return "Matching complete. Those signs are sticking!"
        }
    }
}

struct PracticeCompleteStats: Equatable {
    let leadingSymbol: String
    let leadingValue: String
    let leadingLabel: String
    let trailingSymbol: String?
    let trailingValue: String?
    let trailingLabel: String?

    static func graded(correct: Int, total: Int, bestStreak: Int) -> PracticeCompleteStats {
        PracticeCompleteStats(
            leadingSymbol: "checkmark.circle.fill",
            leadingValue: "\(correct)/\(total)",
            leadingLabel: "Correct",
            trailingSymbol: "flame.fill",
            trailingValue: "\(max(bestStreak, 0))",
            trailingLabel: "Best streak"
        )
    }

    static func flashcards(cardsReviewed: Int) -> PracticeCompleteStats {
        PracticeCompleteStats(
            leadingSymbol: "rectangle.stack.fill",
            leadingValue: "\(cardsReviewed)",
            leadingLabel: "Cards reviewed",
            trailingSymbol: "sparkles",
            trailingValue: nil,
            trailingLabel: nil
        )
    }

    static func matchingRounds(rounds: Int, pairsPerRound: Int) -> PracticeCompleteStats {
        PracticeCompleteStats(
            leadingSymbol: "flag.checkered.2.crossed",
            leadingValue: "\(rounds)",
            leadingLabel: "Rounds",
            trailingSymbol: "link.circle.fill",
            trailingValue: "\(rounds * pairsPerRound)",
            trailingLabel: "Signs matched"
        )
    }

    static func spellYourName(letters: Int, flowReplays: Int) -> PracticeCompleteStats {
        PracticeCompleteStats(
            leadingSymbol: "textformat.abc",
            leadingValue: "\(letters)",
            leadingLabel: "Letters",
            trailingSymbol: "arrow.triangle.2.circlepath",
            trailingValue: "\(max(flowReplays, 1))",
            trailingLabel: "Flow runs"
        )
    }

    static func exercisesCompleted(_ count: Int, bestStreak: Int) -> PracticeCompleteStats {
        if bestStreak > 0 {
            return PracticeCompleteStats(
                leadingSymbol: "flag.checkered.2.crossed",
                leadingValue: "\(count)",
                leadingLabel: "Exercises",
                trailingSymbol: "flame.fill",
                trailingValue: "\(bestStreak)",
                trailingLabel: "Best streak"
            )
        }
        return PracticeCompleteStats(
            leadingSymbol: "flag.checkered.2.crossed",
            leadingValue: "\(count)",
            leadingLabel: "Exercises complete",
            trailingSymbol: nil,
            trailingValue: nil,
            trailingLabel: nil
        )
    }
}

struct PracticeSessionCompleteView: View {
    let mode: PracticeMode
    var stats: PracticeCompleteStats
    let onDone: () -> Void

    @State private var confettiIn = false
    @State private var mascotIn = false
    @State private var contentIn = false
    @State private var buttonIn = false
    @State private var headlineIndex = ASLPracticeCompleteCopy.randomHeadlineIndex()

    private var palette: Color { PracticeTheme.accent }
    private var paletteShadow: Color { PracticeTheme.accentShadow }

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
                        Text(ASLPracticeCompleteCopy.headline(for: mode, index: headlineIndex))
                            .font(.asl(28, weight: .regular, design: .display))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(ASLPracticeCompleteCopy.subtitle(for: mode))
                            .font(.asl(17, weight: .semibold))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    statsRow
                }
                .padding(.horizontal, 24)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? -34 : -10)

                Spacer()

                PressableRaisedUnitButton(
                    title: ASLPracticeCompleteCopy.continueCTA,
                    color: palette,
                    depthColor: paletteShadow,
                    action: onDone
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
                .font(.asl(22, weight: .regular, design: .display))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var statsRow: some View {
        if let trailingSymbol = stats.trailingSymbol,
           let trailingValue = stats.trailingValue,
           let trailingLabel = stats.trailingLabel {
            HStack(spacing: 12) {
                statPill(
                    symbol: stats.leadingSymbol,
                    value: stats.leadingValue,
                    label: stats.leadingLabel
                )
                statPill(symbol: trailingSymbol, value: trailingValue, label: trailingLabel)
            }
        } else {
            statPill(
                symbol: stats.leadingSymbol,
                value: stats.leadingValue,
                label: stats.leadingLabel
            )
        }
    }

    private func statPill(symbol: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.asl(18, weight: .semibold))
                .foregroundStyle(palette)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.asl(17, weight: .semibold))
                Text(label)
                    .font(.asl(12, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
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

struct PracticeUnavailableView: View {
    let mode: PracticeMode

    var body: some View {
        ContentUnavailableView {
            Label(mode.title, systemImage: "books.vertical.fill")
                .foregroundStyle(PracticeTheme.accent)
        } description: {
            Text(mode.emptyStateMessage)
                .foregroundStyle(Brand.secondaryLabel)
        }
        .brandCanvasBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
