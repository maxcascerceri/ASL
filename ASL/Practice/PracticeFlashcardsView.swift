//
//  PracticeFlashcardsView.swift
//  ASL
//

import SwiftUI

struct PracticeFlashcardsView: View {
    @ObservedObject var store: ASLDataStore
    let wordIds: [String]
    var sourceUnitId: String? = nil

    @StateObject private var playerController = LessonPlayerController()
    @State private var shuffledWordIds: [String] = []
    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var showComplete = false
    @State private var navigationButton: ModuleNavigationButtonState = .waiting("Tap the card to reveal")

    @Environment(\.dismiss) private var dismiss

    private enum Layout {
        static let headerTitleSize: CGFloat = 18
        static let headerCountSize: CGFloat = 16
        static let videoHeight: CGFloat = 260
        static let cardTopInset: CGFloat = 6
    }

    private var totalCards: Int { shuffledWordIds.count }

    private var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCards)
    }

    private var currentWordId: String? {
        guard shuffledWordIds.indices.contains(currentIndex) else { return nil }
        return shuffledWordIds[currentIndex]
    }

    var body: some View {
        ZStack {
            LessonShell(
                progress: progress,
                palette: PracticeTheme.accent,
                paletteShadow: PracticeTheme.accentShadow,
                leaveConfirmMessage: PracticeTheme.leaveConfirmMessage
            ) {
                ZStack(alignment: .bottom) {
                    cardContent
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
                    mode: .flashcards,
                    stats: .flashcards(cardsReviewed: totalCards)
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
        .onChange(of: store.mediaCacheRevision) { _, _ in reloadVideo() }
        .onChange(of: store.videoPlaybackRevision) { _, _ in reloadVideo() }
        .onAppear {
            shuffledWordIds = wordIds.shuffled()
            store.loadWords(wordIds: wordIds)
            loadCurrentCard()
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let wordId = currentWordId {
            VStack(spacing: 0) {
                Text("Flashcards")
                    .font(.asl(Layout.headerTitleSize, weight: .medium))
                    .foregroundStyle(Brand.secondaryLabel)
                    .padding(.top, 8)

                Text("\(currentIndex + 1) of \(totalCards)")
                    .font(.asl(Layout.headerCountSize, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel.opacity(0.85))
                    .padding(.top, 4)

                Spacer(minLength: Layout.cardTopInset)

                flashcard(wordId: wordId)
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
            .id(wordId)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        } else {
            ProgressView()
                .padding(.top, 80)
        }
    }

    private func flashcard(wordId: String) -> some View {
        VStack(spacing: 0) {
            videoSection
                .frame(height: Layout.videoHeight)

            if isRevealed {
                VStack(spacing: 8) {
                    Text(wordText(for: wordId))
                        .font(.asl(28, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    revealCard()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Tap to reveal")
                            .font(.asl(16, weight: .semibold))
                    }
                    .foregroundStyle(PracticeTheme.accent)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Brand.chrome)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Brand.divider, lineWidth: 1)
        }
        .elevation(.sheetModal)
    }

    private var videoSection: some View {
        LessonVideoPlayer(
            controller: playerController,
            cornerRadius: SignVideoCardMetrics.innerCornerRadius
        )
        .padding(SignVideoCardMetrics.innerPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Layout.videoHeight)
        .background(Brand.homeBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
    }

    // MARK: - Lifecycle

    private func revealCard() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRevealed = true
        }
        Haptics.tap()
        let isLast = currentIndex + 1 >= totalCards
        navigationButton = .ready(isLast ? "Finish" : "Next")
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }
        advanceCard()
    }

    private func loadCurrentCard() {
        isRevealed = false
        navigationButton = .waiting("Tap the card to reveal")
        guard let wordId = currentWordId else {
            finishSession()
            return
        }
        ensureVideo(for: wordId)
    }

    private func advanceCard() {
        let next = currentIndex + 1
        if next >= totalCards {
            finishSession()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = next
            }
            loadCurrentCard()
        }
    }

    private func finishSession() {
        guard !showComplete else { return }
        store.recordPracticeSessionComplete(mode: .flashcards, unitId: sourceUnitId)
        store.recordDailyActivity()
        store.setPracticeSessionCompleteVisible(true)
        withAnimation(.easeIn(duration: 0.25)) {
            showComplete = true
        }
    }

    // MARK: - Helpers

    private func wordText(for wordId: String) -> String {
        ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId)
    }

    private func reloadVideo() {
        guard let wordId = currentWordId else { return }
        ensureVideo(for: wordId)
    }

    private func ensureVideo(for wordId: String) {
        Task {
            await store.ensureVideoAttached(to: playerController, wordId: wordId)
            playerController.playAtNormalSpeed()
            playerController.replay()
        }
    }
}
