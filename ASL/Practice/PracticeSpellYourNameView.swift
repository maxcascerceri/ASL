//
//  PracticeSpellYourNameView.swift
//  ASL
//

import SwiftUI

struct PracticeSpellYourNameView: View {
    @ObservedObject var store: ASLDataStore
    var initialEntry: SavedFingerspellEntry?
    var initialIntent: FingerspellNameIntent = .personalName
    var skipEntry: Bool = false

    @StateObject private var sequenceController = FingerspellSequenceController()
    @StateObject private var phraseController = LessonPlayerController()
    @State private var session: FingerspellNameSession?
    @State private var pendingClassification: SpellingInputClassification?
    @State private var navigationButton: ModuleNavigationButtonState = .ready("Continue")
    @State private var showComplete = false
    @State private var yourTurnPhase: YourTurnPhase = .watch
    @State private var entrySubmitAction: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LessonShell(
                progress: session?.progress ?? 0,
                palette: PracticeTheme.accent,
                paletteShadow: PracticeTheme.accentShadow,
                leaveConfirmMessage: PracticeTheme.leaveConfirmMessage
            ) {
                ZStack(alignment: .bottom) {
                    content
                        .padding(.bottom, LessonActionTrayLayout.contentInsetAboveTray(for: navigationButton))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    if shouldShowTray {
                        LessonActionTray(
                            state: navigationButton,
                            palette: PracticeTheme.accent,
                            paletteShadow: PracticeTheme.accentShadow,
                            action: tappedNavigationButton
                        )
                    }
                }
            }

            if showComplete, let session {
                PracticeSessionCompleteView(
                    mode: .spellYourName,
                    stats: .spellYourName(
                        letters: session.letterCount,
                        flowReplays: session.stats.flowReplays
                    )
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
        .onAppear {
            if let initialEntry, skipEntry {
                startSession(with: initialEntry)
            }
        }
        .task {
            store.loadWords(wordIds: PracticeAlphabet.letterWordIds)
        }
    }

    private var shouldShowTray: Bool {
        guard let session else { return true }
        if session.phase == .yourTurn, yourTurnPhase == .recording { return false }
        return true
    }

    @ViewBuilder
    private var content: some View {
        if let session {
            sessionContent(session)
        } else if let classification = pendingClassification {
            SpellingCurriculumInterceptView(
                classification: classification,
                store: store,
                onLearnSign: { wordId in
                    store.requestSignDictionary(wordId: wordId)
                    dismiss()
                },
                onSpellAnyway: { proceedAfterIntercept() },
                onPickDifferent: {
                    pendingClassification = nil
                    navigationButton = .ready("Continue")
                }
            )
        } else {
            SpellingEntryView(
                store: store,
                initialText: initialEntry?.displayText ?? "",
                initialIntent: initialIntent,
                onSubmit: handleEntrySubmit,
                onCancel: { dismiss() },
                registerTrayAction: { action in
                    entrySubmitAction = action
                }
            )
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: FingerspellNameSession) -> some View {
        switch session.phase {
        case .entry, .intercept:
            EmptyView()
        case .preview:
            previewContent(session)
        case .learnLetter(let index):
            FingerspellLearnLetterView(
                entry: session.entry,
                letterIndex: index,
                store: store,
                sequenceController: sequenceController,
                isDoubleLetter: session.isDoubleLetter(at: index)
            )
        case .flowPlayback:
            FingerspellFlowPlaybackView(
                entry: session.entry,
                store: store,
                sequenceController: sequenceController,
                onFinished: {
                    navigationButton = .ready("Continue")
                }
            )
        case .yourTurn:
            FingerspellYourTurnView(
                entry: session.entry,
                store: store,
                sequenceController: sequenceController,
                phase: $yourTurnPhase
            )
        case .conversationBridge:
            FingerspellConversationBridgeView(
                entry: session.entry,
                store: store,
                phraseController: phraseController,
                sequenceController: sequenceController
            )
        case .complete:
            Color.clear
                .onAppear { finishSession(session) }
        }
    }

    private func previewContent(_ session: FingerspellNameSession) -> some View {
        VStack(spacing: 16) {
            LessonPromptLabel(text: "Here's your name")
                .padding(.top, 8)
            Text(session.displayText)
                .font(LessonQuestionLayout.teachWordFont)
                .foregroundStyle(Brand.textPrimary)
            FingerspellSequenceVideoPlayer(
                controller: sequenceController,
                height: LessonQuestionLayout.videoHeight,
                showsSlowMotionControl: true
            )
            FingerspellLetterChipStrip(
                letterWordIds: session.letterWordIds,
                onTapIndex: { index in
                    Task {
                        let wordId = session.letterWordIds[index]
                        await sequenceController.loadLetter(wordId: wordId, store: store, loop: true)
                    }
                }
            )
            Text("Tap a letter to preview it.")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .task {
            await sequenceController.preloadSequence(wordIds: session.letterWordIds, store: store)
            if let first = session.letterWordIds.first {
                await sequenceController.loadLetter(wordId: first, store: store, loop: true)
            }
        }
    }

    private func handleEntrySubmit(entry: SavedFingerspellEntry, classification: SpellingInputClassification) {
        switch classification {
        case .curriculumWord, .acronym:
            pendingClassification = classification
            navigationButton = .waiting("Choose an option above")
        default:
            startSession(with: entry)
        }
    }

    private func proceedAfterIntercept() {
        guard let classification = pendingClassification,
              let entry = CurriculumAwareSpellingResolver.makeEntry(
                from: spellingClassificationForBypass(classification),
                intent: .somethingElse
              )
        else { return }
        let saved = FingerspellNameStore.save(entry)
        pendingClassification = nil
        startSession(with: saved)
    }

    private func spellingClassificationForBypass(_ classification: SpellingInputClassification) -> SpellingInputClassification {
        let display = classification.displayText
        let spelling = FingerspellLetterMapper.normalizedSpellingString(from: display)
        let ids = FingerspellLetterMapper.wordIds(for: spelling) ?? []
        return .unknown(displayText: display, spellingText: spelling, letterWordIds: ids)
    }

    private func startSession(with entry: SavedFingerspellEntry) {
        let saved = FingerspellNameStore.save(entry)
        let track: FingerspellSessionTrack = saved.practiceCount > 0 ? .returnVisit : .firstTime
        session = FingerspellNameSession(entry: saved, track: track)
        syncTray(for: session!)
        Task {
            await sequenceController.preloadSequence(wordIds: saved.letterWordIds, store: store)
        }
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        if session == nil {
            entrySubmitAction?()
            return
        }

        guard let session else { return }

        switch session.phase {
        case .preview:
            session.beginLearning()
            syncTray(for: session)
        case .learnLetter:
            session.advanceFromLearn()
            syncTray(for: session)
        case .flowPlayback:
            session.advanceFromFlow()
            yourTurnPhase = .watch
            syncTray(for: session)
        case .yourTurn:
            switch yourTurnPhase {
            case .watch:
                yourTurnPhase = .recording
            case .recording:
                break
            case .review:
                session.advanceFromYourTurn()
                syncTray(for: session)
            }
        case .conversationBridge:
            session.advanceFromBridge()
            syncTray(for: session)
        default:
            break
        }
    }

    private func syncTray(for session: FingerspellNameSession) {
        switch session.phase {
        case .preview:
            navigationButton = .ready("Start learning")
        case .learnLetter(let index):
            let isLast = index + 1 >= session.letterCount
            navigationButton = .ready(isLast ? "Put it together" : "Next letter")
        case .flowPlayback:
            navigationButton = .waiting(session.isReturnVisit ? "Watch the full spelling…" : "Watch your name…")
        case .yourTurn:
            switch yourTurnPhase {
            case .watch:
                navigationButton = .ready("Record now")
            case .recording:
                navigationButton = .ready("Record now")
            case .review:
                navigationButton = .ready("Continue")
            }
        case .conversationBridge:
            navigationButton = .ready("Finish")
        case .complete:
            navigationButton = .ready("Done")
        default:
            navigationButton = .ready("Continue")
        }
    }

    private func finishSession(_ session: FingerspellNameSession) {
        guard !showComplete else { return }
        session.phase = .complete
        FingerspellNameStore.recordPractice(for: session.entry.id)
        store.recordPracticeSessionComplete(mode: .spellYourName)
        store.recordDailyActivity()
        store.setPracticeSessionCompleteVisible(true)
        withAnimation(.easeIn(duration: 0.25)) {
            showComplete = true
        }
    }
}
