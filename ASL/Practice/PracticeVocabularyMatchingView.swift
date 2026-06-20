//
//  PracticeVocabularyMatchingView.swift
//  ASL
//

import SwiftUI

struct PracticeVocabularyMatchingView: View {
    @ObservedObject var store: ASLDataStore
    let pool: [String]

    @State private var roundIndex = 0
    @State private var roundWordIds: [String] = []
    @State private var showComplete = false
    @State private var navigationButton: ModuleNavigationButtonState = .waiting("Match each sign to its word")
    @State private var correctFeedbackIndex = 0
    @State private var continueActionTitleIndex = 0
    @StateObject private var playerController = LessonPlayerController()

    @Environment(\.dismiss) private var dismiss

    private let maxRounds = 5
    private let pairsPerRound = 4

    var body: some View {
        ZStack {
            LessonShell(progress: shellProgress, palette: PracticeTheme.accent, paletteShadow: PracticeTheme.accentShadow, leaveConfirmMessage: PracticeTheme.leaveConfirmMessage) {
                ZStack(alignment: .bottom) {
                    boardContent
                        .padding(.bottom, LessonActionTrayLayout.expandedReservedHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    LessonActionTray(
                        state: navigationButton,
                        palette: PracticeTheme.accent,
                        paletteShadow: PracticeTheme.accentShadow,
                        action: tappedNavigationButton
                    )
                }
            }

            if showComplete {
                PracticeSessionCompleteView(
                    mode: .vocabularyMatch,
                    stats: .matchingRounds(rounds: maxRounds, pairsPerRound: pairsPerRound)
                ) {
                    store.setPracticeSessionCompleteVisible(false)
                    dismiss()
                }
                .transition(.opacity)
                .zIndex(80)
            }
        }
        .preference(key: CustomTabBarHiddenPreferenceKey.self, value: true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { startRound() }
        .task(id: pool) {
            store.loadWords(wordIds: pool)
        }
    }

    @ViewBuilder
    private var boardContent: some View {
        if roundWordIds.isEmpty {
            ProgressView()
                .padding(.top, 80)
        } else {
            MatchPairsBoardView(
                wordIds: roundWordIds,
                prompt: "Match each sign to its word.",
                palette: PracticeTheme.accent,
                paletteShadow: PracticeTheme.accentShadow,
                store: store,
                playerController: playerController,
                wordTitle: wordText(for:)
            ) {
                handleRoundComplete()
            }
            .id(roundIndex)
        }
    }

    private var shellProgress: Double {
        guard maxRounds > 0 else { return 0 }
        return Double(min(roundIndex, maxRounds)) / Double(maxRounds)
    }

    private func startRound() {
        guard roundIndex < maxRounds else {
            finishSession()
            return
        }
        var rng = SeededRandomNumberGenerator(seed: StableSeed.fnv1a64("vocab-match:\(roundIndex):\(pool.hashValue)"))
        let count = min(pairsPerRound, pool.count)
        roundWordIds = Array(pool.shuffled(using: &rng).prefix(count))
        roundIndex += 1
        navigationButton = .waiting("Match each sign to its word")
    }

    private func handleRoundComplete() {
        let isLastRound = roundIndex >= maxRounds
        navigationButton = .correct(
            headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
            actionTitle: isLastRound ? "Finish" : PracticeContinueCopy.nextAction(index: &continueActionTitleIndex)
        )
        correctFeedbackIndex += 1
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        guard case .correct = navigationButton else { return }

        if roundIndex >= maxRounds {
            finishSession()
        } else {
            startRound()
        }
    }

    private func finishSession() {
        guard !showComplete else { return }
        store.recordPracticeSessionComplete(mode: .vocabularyMatch)
        store.recordDailyActivity()
        store.setPracticeSessionCompleteVisible(true)
        withAnimation(.easeIn(duration: 0.25)) {
            showComplete = true
        }
    }

    private func wordText(for wordId: String) -> String {
        ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId)
    }
}
