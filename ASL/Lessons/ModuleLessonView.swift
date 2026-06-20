//
//  ModuleLessonView.swift
//  ASL
//
//  Mixed-step stone engine. A module can interleave teach beats, recognition
//  checks, context prompts, video comparisons, and recall prompts in one flow.
//

import AVKit
import SwiftUI
import UIKit

struct ModuleLessonView: View {
    let lesson: ASLLesson
    let unit: ASLUnit
    @ObservedObject var store: ASLDataStore

    @StateObject private var session: StoneSession<ModulePlayStep>
    @StateObject private var playerController = LessonPlayerController()
    @State private var attachedVideoWordId: String?
    @State private var tileStates: [ChoiceTileState] = []
    @State private var lockTaps = false
    @State private var showStoneCelebration = false
    @State private var showUnitCelebration = false
    @State private var navigationButton: ModuleNavigationButtonState = .waiting("Choose an answer")
    @State private var wrongFeedbackIndex = 0
    @State private var correctFeedbackIndex = 0
    @State private var continueActionTitleIndex = 0
    @State private var pendingStreakCount: Int?
    @State private var showStreakCelebration = false
    @State private var streakCelebrationCount = 0
    /// Steps the user got wrong during the initial pass; replayed during the
    /// redrill phase so the lesson can't complete until every miss is cleared.
    @State private var missedSteps: [ModulePlayStep] = []
    /// True once the user has been moved into the post-pass Review Mode loop.
    @State private var isRedrillPhase = false
    @State private var showRedrillIntro = false
    /// Pending tile reset for the Review Mode "wrong, try again" flow.
    @State private var redrillResetWorkItem: DispatchWorkItem?
    @State private var delayedChoicesVisible = false
    @State private var modulePickRevealCountdown: Int?
    @State private var modulePickRevealWorkItems: [DispatchWorkItem] = []
    @State private var selectedChoiceIndex: Int?
    @State private var selectedChoiceWordId: String?
    @State private var signSequenceFilled: [String] = []
    @State private var matchBoardWordIds: [String] = []
    @State private var matchRemainingWordIds: [String] = []
    @State private var matchResolvedWordIds: Set<String> = []
    @State private var matchPlayColumnOrder: [String] = []
    @State private var matchTranslationColumnOrder: [String] = []
    @State private var selectedMatchVideoWordId: String?
    @State private var selectedMatchTranslationWordId: String?
    @State private var matchMissRecorded = false
    @State private var matchPairFlash: MatchPairFlash?
    @State private var matchPairFeedbackWorkItem: DispatchWorkItem?
    @State private var stoneCompletionAward = StoneCompletionAward.zero
    @State private var showPhaseReviewIntro = false
    @State private var showPhaseReviewComplete = false
    @State private var phaseReviewRoundBanner: PhaseReviewRound?
    @State private var lastShownPhaseReviewRound: PhaseReviewRound?
    @State private var phaseReviewRoundBannerWorkItem: DispatchWorkItem?
    @State private var yourTurnPhase: YourTurnPhase = .watch
    @State private var showAppStoreReview = false
    @State private var firstPassStepCount: Int = 0
    @State private var firstPassGradedCount: Int = 0
    @State private var firstPassCompleted: Int = 0
    @State private var pendingReviewStepCount: Int = 0
    /// Graded-question stats for the full stone (initial pass + redrill), preserved
    /// when `StoneSession.reload` resets per-phase session counters.
    @State private var stoneSessionCorrectCount = 0
    @State private var stoneSessionBestStreak = 0

    private let phaseReviewRoundPlan: PhaseReviewRoundPlan?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lessonPortalDismiss) private var portalDismiss
    @Environment(LessonEntryRevealCoordinator.self) private var lessonEntryRevealCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pathIntroducedAtLessonStart: Set<String>

    init(lesson: ASLLesson, unit: ASLUnit, store: ASLDataStore) {
        self.lesson = lesson
        self.unit = unit
        self.store = store
        pathIntroducedAtLessonStart = store.introducedWordIdsOnPath
        let steps = store.modulePlaySteps(for: lesson)
        phaseReviewRoundPlan = unit.isPhaseReview ? PhaseReviewRoundPlan.build(from: steps) : nil
        let savedIndex = store.savedStepIndex(for: lesson.id, totalSteps: steps.count)
        _session = StateObject(wrappedValue: StoneSession(
            questions: steps,
            startIndex: Self.safeResumeStepIndex(
                saved: savedIndex,
                steps: steps,
                lesson: lesson
            )
        ))
    }

    var body: some View {
        ZStack {
            if shouldShowLessonChrome {
                LessonShell(
                    progress: lessonDisplayProgress,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor,
                    showReset: store.shouldOfferStoneReset(
                        lessonId: lesson.id,
                        sessionProgress: lessonDisplayProgress
                    ),
                    onLeave: saveLessonProgressOnExit,
                    onReset: resetStone,
                    headerCaption: phaseReviewHeaderCaption,
                    roundSegmentFills: phaseReviewSegmentFills
                ) {
                    ZStack(alignment: .bottom) {
                        ZStack(alignment: .top) {
                            content
                                .padding(.top, lessonContentTopPadding)
                                .padding(.bottom, lessonContentBottomInset)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .clipped()

                            if isRedrillPhase {
                                ReviewModeLabel(palette: paletteColor)
                                    .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
                                    .padding(.top, 10)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .transition(.opacity)
                                    .zIndex(20)
                            }

                            if let phaseReviewRoundBanner {
                                MatchPairMicrocopyBanner(text: phaseReviewRoundBanner.title, palette: paletteColor)
                                    .padding(.top, 12)
                                    .transition(.scale.combined(with: .opacity))
                                    .zIndex(20)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        moduleNavigationButton
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if showStoneCelebration {
                ModuleCompleteCelebration(
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor,
                    starAward: stoneCompletionAward,
                    correctCount: stoneCelebrationCorrectCount,
                    totalCount: stoneCelebrationGradedTotal,
                    bestStreak: stoneCelebrationBestStreak,
                    continueTitle: stoneCelebrationContinueTitle,
                    onContinue: continueAfterStoneCelebration
                )
                .transition(.opacity)
            }

            if showAppStoreReview {
                OnboardingAppStoreReviewView(
                    onAppearRequest: {
                        guard AppStoreReviewPrompt.shouldShowFirstUnitOneStonePrompt else { return }
                        AppStoreReviewPrompt.markFirstUnitOneStonePromptShown()
                        AppStoreReviewPrompt.requestReviewIfPossible()
                    },
                    onContinue: dismissAppStoreReview
                )
                .transition(.opacity)
                .zIndex(80)
            }

            if showUnitCelebration {
                UnitCelebration(
                    unit: unit,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor,
                    starAward: stoneCompletionAward,
                    bestStreak: stoneCelebrationBestStreak,
                    signsInUnit: PracticePathContext.wordIds(forUnitId: unit.id, store: store).count,
                    nextUnit: nextPlayableUnit,
                    nextUnitPalette: nextUnitPaletteColor,
                    nextUnitPaletteShadow: nextUnitPaletteShadowColor,
                    onContinue: continueAfterUnitCompletion
                )
                .transition(.opacity)
            }

            if showStreakCelebration {
                StreakCelebration(
                    streak: streakCelebrationCount,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    dismissStreakCelebration()
                }
                .transition(.opacity)
                .zIndex(60)
            }

            if showRedrillIntro {
                RedrillIntroView(
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    startRedrill()
                }
                .transition(.opacity)
                .zIndex(70)
            }

            if showPhaseReviewIntro {
                PhaseReviewIntroView(
                    phaseTitle: unit.phaseTitle ?? unit.title,
                    phaseKey: unit.phaseKey,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    beginPhaseReview()
                }
                .transition(.opacity)
                .zIndex(75)
            }

            if showPhaseReviewComplete {
                PhaseReviewCompleteCelebration(
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor,
                    phaseTitle: unit.phaseTitle ?? unit.title,
                    phaseKey: unit.phaseKey ?? "",
                    starAward: stoneCompletionAward,
                    correctCount: stoneCelebrationCorrectCount,
                    totalCount: stoneCelebrationGradedTotal,
                    bestStreak: stoneCelebrationBestStreak,
                    nextUnit: nextPlayableUnit,
                    nextUnitPalette: nextUnitPaletteColor,
                    nextUnitPaletteShadow: nextUnitPaletteShadowColor,
                    onContinue: continueAfterUnitCompletion
                )
                .transition(.opacity)
                .zIndex(80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: session.currentIndex) { _, _ in startStep() }
        .onChange(of: store.wordsById.count) { _, _ in loadCurrentVideoIfReady() }
        .onChange(of: store.mediaCacheRevision) { _, _ in loadCurrentVideoIfReady() }
        .onChange(of: store.videoPlaybackRevision) { _, _ in loadCurrentVideoIfReady() }
        .onChange(of: store.videosByWordId.count) { _, _ in loadCurrentVideoIfReady() }
        .onAppear {
            if shouldShowPhaseReviewIntroOnLaunch {
                withAnimation(.easeIn(duration: 0.2)) { showPhaseReviewIntro = true }
            } else {
                startStep()
            }
        }
        .onDisappear {
            store.endLessonMediaSession(lessonId: lesson.id)
            cancelModulePickReveal()
            redrillResetWorkItem?.cancel()
            cancelMatchPairFeedbackWorkItem()
            cancelPhaseReviewRoundBanner()
        }
    }

    private var shouldShowPhaseReviewIntroOnLaunch: Bool {
        unit.isPhaseReview
            && store.lessonProgress(for: lesson.id) == 0
            && !isRedrillPhase
    }

    private var phaseReviewHeaderCaption: String? {
        guard unit.isPhaseReview, let plan = phaseReviewRoundPlan else { return nil }
        return plan.headerCaption(for: session.currentIndex)
    }

    private var phaseReviewSegmentFills: [Double]? {
        guard unit.isPhaseReview, let plan = phaseReviewRoundPlan else { return nil }
        return plan.segmentFills(completedThrough: session.currentIndex)
    }

    private var lessonContentTopPadding: CGFloat {
        let reviewBand: CGFloat = isRedrillPhase ? 32 : 0
        return reviewBand + 52 + LessonActionTrayLayout.verticalNudge
    }

    /// Match-pairs keeps a compact content inset so the tray can expand upward
    /// for feedback without reflowing the board and shifting the CTA lane down.
    private var lessonContentBottomInset: CGFloat {
        if case .matchPairs = session.current {
            return LessonActionTrayLayout.compactReservedHeight
        }
        return LessonActionTrayLayout.contentInsetAboveTray(for: navigationButton)
    }

    private var lessonDisplayProgress: Double {
        guard firstPassStepCount > 0 else { return session.progress }
        if isRedrillPhase || showRedrillIntro {
            let reviewTotal = isRedrillPhase ? session.total : pendingReviewStepCount
            let totalWork = firstPassCompleted + reviewTotal
            guard totalWork > 0 else { return 1 }
            let completed = firstPassCompleted + (isRedrillPhase ? session.currentIndex : 0)
            return Double(completed) / Double(totalWork)
        }
        return Double(session.currentIndex) / Double(firstPassStepCount)
    }

    private var shouldShowLessonChrome: Bool {
        session.current != nil
        && !showStoneCelebration
        && !showAppStoreReview
        && !showUnitCelebration
        && !showRedrillIntro
        && !showPhaseReviewIntro
        && !showPhaseReviewComplete
    }

    @ViewBuilder
    private var content: some View {
        if let step = session.current {
            switch step {
            case .teach(let item):
                teachContent(item: item)
            case .wordPickVideo(let item):
                wordPickVideoContent(item: item)
            case .watchChoose(let item):
                watchChooseContent(item: item)
            case .translationChoose(let item):
                translationChooseContent(item: item)
            case .signSequence(let item):
                signSequenceContent(item: item)
            case .phraseSlot(let item):
                phraseSlotContent(item: item)
            case .fillSlot(let item):
                fillSlotContent(item: item)
            case .matchPairs(let item):
                matchPairsContent(item: item)
            case .yourTurn(let item):
                yourTurnContent(item: item)
            case .aslTip(let item):
                aslTipContent(item: item)
            }
        } else {
            EmptyView()
        }
    }

    private func yourTurnContent(item: ModuleTeachItem) -> some View {
        YourTurnStepView(
            lessonId: lesson.id,
            referenceWordId: item.wordId,
            title: item.title,
            prompt: item.prompt,
            phase: $yourTurnPhase,
            store: store,
            palette: paletteColor,
            paletteShadow: paletteShadowColor
        )
        .id(item.id)
        .transition(stepTransition)
        .onChange(of: yourTurnPhase) { _, phase in
            syncYourTurnTray(for: phase)
        }
    }

    private func aslTipContent(item: ASLTipItem) -> some View {
        ASLTipStepView(
            item: item,
            store: store,
            palette: paletteColor,
            paletteShadow: paletteShadowColor
        )
        .id(item.id)
        .transition(stepTransition)
        .onAppear {
            store.markASLTipSeen(item.tipId)
        }
    }

    private func teachContent(item: ModuleTeachItem) -> some View {
        LessonStepStack {
            LessonPromptLabel(
                text: item.title.isEmpty ? "New sign!" : item.title
            )
        } media: {
            moduleVideo(height: LessonQuestionLayout.videoHeight)
        } controls: {
            Text(wordText(for: item.wordId))
                .font(LessonQuestionLayout.teachWordFont)
                .foregroundStyle(paletteColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .id(item.id)
        .transition(stepTransition)
    }

    private func wordPickVideoContent(item: WordPickVideoItem) -> some View {
        let wordLabel = wordText(for: item.answerWordId)
        let isPhraseAnswer = ASLPhraseIds.contains(item.answerWordId)
        return LessonStepStack(
            spacing: 14,
            title: {
                if isPhraseAnswer {
                    moduleQuestionPrompt(
                        text: "Match this phrase.",
                        answerWordId: item.answerWordId,
                        subtitle: wordLabel
                    )
                } else {
                    moduleQuestionPrompt(
                        text: item.prompt,
                        answerWordId: item.answerWordId
                    )
                }
            },
            media: {
                SelectableStackedVideoChoiceView(
                    wordIds: item.choices,
                    selectedWordId: selectedChoiceWordId,
                    tileStates: tileStates,
                    store: store,
                    height: LessonQuestionLayout.wordPickVideoCardHeight,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) { index, picked in
                    selectChoice(index: index, picked: picked)
                }
                .padding(.horizontal, 6)
            },
            controls: {
                EmptyView()
            }
        )
        .padding(.horizontal, 18)
        .id(item.id)
        .transition(stepTransition)
    }

    private func watchChooseContent(item: ModulePickItem) -> some View {
        lessonStepStack(
            title: {
                moduleQuestionPrompt(text: item.prompt, answerWordId: item.answerWordId)
            },
            media: {
                moduleVideo(height: LessonQuestionLayout.videoHeight)
            },
            controls: {
                selectableChoiceGrid(choices: item.choices) { index, picked in
                    selectChoice(index: index, picked: picked)
                }
            }
        )
        .id(item.id)
        .transition(stepTransition)
    }

    private func translationChooseContent(item: ModulePickItem) -> some View {
        lessonStepStack(
            spacing: 14,
            title: {
                moduleQuestionPrompt(text: item.prompt, answerWordId: item.answerWordId)
            },
            media: {
                moduleVideo(height: LessonQuestionLayout.videoHeight)
            },
            controls: {
                selectableChoiceGrid(choices: item.choices) { index, picked in
                    selectChoice(index: index, picked: picked)
                }
            }
        )
        .id(item.id)
        .transition(stepTransition)
    }

    private func fillSlotContent(item: FillGapPlayItem) -> some View {
        lessonStepStack(
            spacing: 14,
            title: {
                moduleQuestionPrompt(text: item.prompt, answerWordId: item.answerWordId)
            },
            media: {
                VStack(spacing: 14) {
                    if let phraseWordId = item.phraseWordId {
                        phraseVideoPlate(wordId: phraseWordId, height: 240)
                    } else {
                        moduleVideo(height: 240)
                    }
                    HStack(spacing: 6) {
                        Text(item.before)
                            .font(LessonQuestionLayout.sentenceFont)
                        fillSlotChip
                        Text(item.after)
                            .font(LessonQuestionLayout.sentenceFont)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .animation(nil, value: selectedChoiceWordId)
                }
            },
            controls: {
                selectableChoiceGrid(choices: item.choices) { index, picked in
                    selectChoice(index: index, picked: picked)
                }
            }
        )
        .id(item.id)
        .transition(stepTransition)
    }

    private func phraseSlotContent(item: PhraseSlotItem) -> some View {
        lessonStepStack(
            spacing: 14,
            title: {
                moduleQuestionPrompt(text: item.prompt, answerWordId: item.answerWordId)
            },
            media: {
                VStack(spacing: 14) {
                    phraseVideoPlate(wordId: item.phraseWordId, height: 240)
                    HStack(spacing: 8) {
                        ForEach(Array(item.sequenceWordIds.indices), id: \.self) { index in
                            phraseSlotStripCell(
                                wordId: index == item.slotIndex ? nil : item.sequenceWordIds[index],
                                phraseWordId: item.phraseWordId
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            },
            controls: {
                selectableChoiceGrid(choices: item.choices, phraseId: item.phraseWordId) { index, picked in
                    selectChoice(index: index, picked: picked)
                }
            }
        )
        .id(item.id)
        .transition(stepTransition)
    }

    private func phraseSlotStripCell(wordId: String?, phraseWordId: String) -> some View {
        ZStack {
            if let wordId {
                Text(wordText(for: wordId, phraseId: phraseWordId))
                    .font(LessonQuestionLayout.chipFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 8)
            }
        }
        .frame(minWidth: 56, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wordId == nil ? paletteColor.opacity(0.14) : paletteColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(paletteColor.opacity(wordId == nil ? 0.5 : 0.85), lineWidth: wordId == nil ? 2 : 2.5)
        )
    }

    private func signSequenceContent(item: SignSequenceItem) -> some View {
        lessonStepStack(
            spacing: 12,
            title: {
                moduleQuestionPrompt(text: item.prompt)
            },
            media: {
                phraseVideoPlate(wordId: item.phraseWordId, height: 220)
            },
            controls: {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(Array(item.sequenceWordIds.indices), id: \.self) { index in
                            signSequenceSlot(
                                wordId: index < signSequenceFilled.count ? signSequenceFilled[index] : nil,
                                phraseWordId: item.phraseWordId,
                                onUndo: { undoSignSequenceSlot(at: index) }
                            )
                        }
                    }
                    .animation(nil, value: signSequenceFilled)

                    signSequenceChoiceGrid(item: item)
                }
            }
        )
        .id(item.id)
        .transition(stepTransition)
    }

    private func signSequenceChoiceGrid(item: SignSequenceItem) -> some View {
        let choices = signSequenceChoicePool(for: item)
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: LessonQuestionLayout.choiceSpacing) {
            ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                let isUsed = signSequenceFilled.contains(choice)
                ChoiceTile(
                    label: wordText(for: choice, phraseId: item.phraseWordId),
                    state: isUsed ? .dimmed : .rest,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    guard !isUsed else { return }
                    appendSignSequencePick(choice, item: item)
                }
            }
        }
    }

    @ViewBuilder
    private func phraseVideoPlate(wordId: String, height: CGFloat = 210) -> some View {
        LessonVideoStage(
            controller: playerController,
            wordId: wordId,
            store: store,
            height: height,
            placeholderColor: Brand.homeBackground,
            showsControls: true
        )
    }

    private func matchPairsContent(item: MatchPairsItem) -> some View {
        MatchPairsStepLayout(
            prompt: item.prompt,
            promptEyebrow: signRefresherEyebrowText,
            pairCount: item.wordIds.count,
            compactControlsPlacement: true
        ) {
            moduleVideo(height: MatchPairLayout.videoHeight, wordId: selectedMatchVideoWordId)
        } controls: {
            MatchPairControlsRow(
                wordColumnWidth: MatchPairLayout.wordTileWidth(
                    for: matchTranslationColumnOrder.map { wordText(for: $0) }
                )
            ) {
                ForEach(matchPlayColumnOrder, id: \.self) { wordId in
                    let flash = matchPairPlayFlashStates(for: wordId)
                    MatchPairPlayTile(
                        palette: paletteColor,
                        paletteShadow: paletteShadowColor,
                        isSelected: selectedMatchVideoWordId == wordId,
                        isResolved: matchResolvedWordIds.contains(wordId),
                        flashWrong: flash.wrong,
                        flashCorrect: flash.correct,
                        accessibilitySignLabel: wordText(for: wordId)
                    ) {
                        selectMatchVideo(wordId)
                    }
                }
            } wordColumn: {
                ForEach(matchTranslationColumnOrder, id: \.self) { wordId in
                    let flash = matchPairWordFlashStates(for: wordId)
                    MatchPairWordTile(
                        title: wordText(for: wordId),
                        palette: paletteColor,
                        paletteShadow: paletteShadowColor,
                        isSelected: selectedMatchTranslationWordId == wordId,
                        isResolved: matchResolvedWordIds.contains(wordId),
                        flashWrong: flash.wrong,
                        flashCorrect: flash.correct
                    ) {
                        selectMatchTranslation(wordId)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .id(item.id)
        .transition(stepTransition)
        .onChange(of: selectedMatchVideoWordId) { _, newValue in
            guard case .matchPairs = session.current else { return }
            guard newValue == nil, !matchRemainingWordIds.isEmpty else { return }
            selectFirstAvailableMatchVideo()
        }
    }

    private func moduleVideo(height: CGFloat = LessonQuestionLayout.videoHeight, wordId: String? = nil) -> some View {
        LessonVideoStage(
            controller: playerController,
            wordId: wordId ?? currentVideoWordId,
            store: store,
            height: height,
            placeholderColor: Brand.homeBackground,
            showsControls: true
        )
    }

    private func lessonStepStack<Title: View, Media: View, Controls: View>(
        spacing: CGFloat = LessonQuestionLayout.sectionSpacing,
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder media: @escaping () -> Media,
        @ViewBuilder controls: @escaping () -> Controls
    ) -> some View {
        LessonStepStack(spacing: spacing, title: title, media: media, controls: controls)
            .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }

    private var signRefresherEyebrowText: String? {
        guard let step = session.current else { return nil }
        guard Self.showsSignRefresherEyebrow(
            for: step,
            lesson: lesson,
            unit: unit,
            isRedrillPhase: isRedrillPhase,
            pathIntroducedAtLessonStart: pathIntroducedAtLessonStart,
            stepIndex: session.currentIndex,
            playSteps: session.questions
        ) else { return nil }
        return "Refresher."
    }

    private func moduleQuestionPrompt(
        text: String,
        answerWordId: String? = nil,
        emphasizedSegment: String? = nil,
        useInstructionWeight: Bool = false,
        subtitle: String? = nil
    ) -> LessonPromptLabel {
        let eyebrow = signRefresherEyebrowText
        let resolvedAnswerWordId: String?
        if let answerWordId {
            resolvedAnswerWordId = answerWordId
        } else if let step = session.current {
            resolvedAnswerWordId = Self.pickAnswerWordId(for: step)
        } else {
            resolvedAnswerWordId = nil
        }
        let wordLabel = resolvedAnswerWordId.map { wordText(for: $0) }

        let baseText = wordLabel.map { label in
            text.replacingOccurrences(of: "{word}", with: label)
        } ?? text

        let displayText = eyebrow == nil
            ? baseText
            : Self.signRefresherExerciseTitle(
                for: session.current,
                fallback: baseText,
                lessonId: lesson.id,
                stepIndex: session.currentIndex,
                wordLabel: { wordText(for: $0) }
            )

        let autoEmphasis = wordLabel.flatMap {
            LessonPromptLabel.emphasisSegment(forPrompt: baseText, wordLabel: $0, in: displayText)
        }
        let displayEmphasis = emphasizedSegment ?? autoEmphasis
        let subtitleWeight: Font.Weight = subtitle != nil && resolvedAnswerWordId != nil
            ? LessonQuestionLayout.promptEmphasisWeight
            : .semibold

        return LessonPromptLabel(
            text: displayText,
            emphasizedSegment: displayEmphasis,
            useInstructionWeight: useInstructionWeight,
            subtitle: subtitle,
            subtitleWeight: subtitleWeight,
            eyebrow: eyebrow,
            eyebrowStyle: eyebrow == nil ? .standard : .refresher,
            emphasisColor: paletteColor,
            subtitleForeground: subtitle != nil ? paletteColor : nil
        )
    }

    private func choiceGrid(choices: [String], tapped: @escaping (Int, String) -> Void) -> some View {
        labeledChoiceGrid(choices: choices, labels: choices.map { wordText(for: $0) }, tapped: tapped)
    }

    private func selectableChoiceGrid(choices: [String],
                                      phraseId: String? = nil,
                                      isEnabled: Bool = true,
                                      tapped: @escaping (Int, String) -> Void) -> some View {
        selectableLabeledChoiceGrid(
            choices: choices,
            labels: choices.map { wordText(for: $0, phraseId: phraseId) },
            isEnabled: isEnabled,
            tapped: tapped
        )
    }

    private func choiceTileState(at index: Int, isSelected: Bool) -> ChoiceTileState {
        if tileStates.indices.contains(index), tileStates[index] != .rest {
            return tileStates[index]
        }
        return isSelected ? .selected : .rest
    }

    private func selectableLabeledChoiceGrid(choices: [String],
                                             labels: [String],
                                             isEnabled: Bool = true,
                                             tapped: @escaping (Int, String) -> Void) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: LessonQuestionLayout.choiceSpacing) {
            ForEach(Array(choices.enumerated()), id: \.offset) { idx, choice in
                let isSelected = selectedChoiceIndex == idx
                ChoiceTile(
                    label: labels.indices.contains(idx) ? labels[idx] : choice,
                    state: choiceTileState(at: idx, isSelected: isSelected),
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    guard isEnabled else { return }
                    tapped(idx, choice)
                }
                .allowsHitTesting(isEnabled)
            }
        }
    }

    private func labeledChoiceGrid(choices: [String],
                                   labels: [String],
                                   tapped: @escaping (Int, String) -> Void) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: LessonQuestionLayout.choiceSpacing) {
            ForEach(Array(choices.enumerated()), id: \.offset) { idx, choice in
                ChoiceTile(
                    label: labels.indices.contains(idx) ? labels[idx] : choice,
                    state: tileStates.indices.contains(idx) ? tileStates[idx] : .rest,
                    palette: paletteColor,
                    paletteShadow: paletteShadowColor
                ) {
                    tapped(idx, choice)
                }
            }
        }
    }

    private var moduleNavigationButton: some View {
        LessonActionTray(
            state: navigationButton,
            palette: paletteColor,
            paletteShadow: paletteShadowColor,
            action: tappedNavigationButton
        )
    }

    private func saveLessonProgressOnExit() {
        guard !isRedrillPhase else { return }
        let steps = store.modulePlaySteps(for: lesson)
        let totalSteps = max(steps.count, 1)
        store.updateLessonProgress(
            lessonId: lesson.id,
            currentIndex: session.currentIndex,
            totalSteps: totalSteps,
            isComplete: false
        )
    }

    private func dismissLesson() {
        portalDismiss?()
        dismiss()
    }

    private func continueAfterStoneCelebration() {
        showStoneCelebration = false
        if shouldShowFirstUnitOneStoneReview {
            withAnimation(.easeIn(duration: 0.2)) {
                showAppStoreReview = true
            }
        } else {
            continueToNextStoneOrDismiss()
        }
    }

    private func dismissAppStoreReview() {
        guard showAppStoreReview else { return }
        showAppStoreReview = false
        continueToNextStoneOrDismiss()
    }

    private var nextStoneLesson: ASLLesson? {
        guard lesson.sortOrder <= 2 else { return nil }
        return (store.lessonsByUnitId[unit.id] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .first { $0.sortOrder == lesson.sortOrder + 1 }
    }

    private var stoneCelebrationContinueTitle: String {
        if let nextStone = nextStoneLesson {
            return ASLModuleCompleteCopy.nextStoneCTA(nextStone: nextStone, unit: unit)
        }
        return ASLModuleCompleteCopy.continueCTA
    }

    private func continueToNextStoneOrDismiss() {
        guard lesson.sortOrder <= 2, let nextStone = nextStoneLesson else {
            dismissLesson()
            return
        }
        handoffToNextUnitLesson(nextStone, in: unit)
    }

    private var shouldShowFirstUnitOneStoneReview: Bool {
        isFirstStoneInUnitOne && AppStoreReviewPrompt.shouldShowFirstUnitOneStonePrompt
    }

    private var isFirstStoneInUnitOne: Bool {
        unit.id == "p1-u01" && lesson.sortOrder == 1
    }

    private func resetStone() {
        store.resetLessonProgress(lessonId: lesson.id, unitId: unit.id)
        store.invalidateModulePlayStepsCache(forUnitId: unit.id)
        let steps = store.modulePlaySteps(for: lesson)
        session.reload(with: steps)
        isRedrillPhase = false
        showRedrillIntro = false
        missedSteps = []
        showStoneCelebration = false
        showAppStoreReview = false
        showUnitCelebration = false
        showPhaseReviewIntro = false
        showPhaseReviewComplete = false
        lastShownPhaseReviewRound = nil
        cancelPhaseReviewRoundBanner()
        showStreakCelebration = false
        pendingStreakCount = nil
        streakCelebrationCount = 0
        stoneCompletionAward = .zero
        wrongFeedbackIndex = 0
        correctFeedbackIndex = 0
        continueActionTitleIndex = 0
        redrillResetWorkItem?.cancel()
        cancelModulePickReveal()
        cancelMatchPairFeedbackWorkItem()
        firstPassStepCount = 0
        firstPassGradedCount = 0
        firstPassCompleted = 0
        pendingReviewStepCount = 0
        stoneSessionCorrectCount = 0
        stoneSessionBestStreak = 0
        startStep()
    }

    private func ensureFirstPassStepCount() {
        guard firstPassStepCount == 0, !isRedrillPhase else { return }
        let steps = store.modulePlaySteps(for: lesson)
        firstPassStepCount = max(steps.count, 1)
        firstPassGradedCount = Self.gradedQuestionTotal(for: steps)
    }

    private static func gradedQuestionTotal(for steps: [ModulePlayStep]) -> Int {
        max(steps.filter(\.isGradedQuestionStep).count, 1)
    }

    private func gradedQuestionTotal(for steps: [ModulePlayStep]) -> Int {
        Self.gradedQuestionTotal(for: steps)
    }

    private var stoneCelebrationCorrectCount: Int {
        stoneSessionCorrectCount
    }

    private var stoneCelebrationGradedTotal: Int {
        max(firstPassGradedCount, gradedQuestionTotal(for: session.questions))
    }

    private var stoneCelebrationBestStreak: Int {
        max(stoneSessionBestStreak, session.bestStreak)
    }

    /// Records a graded correct answer for the active session phase and accumulates
    /// stone-wide stats used on the completion celebration after redrill.
    private func recordGradedCorrect() {
        session.recordCorrect()
        stoneSessionCorrectCount += 1
        stoneSessionBestStreak = max(stoneSessionBestStreak, session.bestStreak)
    }

    private func startStep() {
        ensureFirstPassStepCount()
        cancelModulePickReveal()
        cancelMatchPairFeedbackWorkItem()
        matchPairFlash = nil
        delayedChoicesVisible = false
        signSequenceFilled = []
        lockTaps = false
        selectedChoiceIndex = nil
        selectedChoiceWordId = nil
        selectedMatchVideoWordId = nil
        selectedMatchTranslationWordId = nil
        matchMissRecorded = false
        matchBoardWordIds = []
        matchRemainingWordIds = []
        matchResolvedWordIds = []
        matchPlayColumnOrder = []
        matchTranslationColumnOrder = []
        playerController.setSlowMotion(false)

        guard let step = session.current else {
            finishModule()
            return
        }

        maybeShowPhaseReviewRoundBanner(for: step)

        switch step {
        case .teach, .aslTip:
            tileStates = []
            navigationButton = .ready("Continue")
        case .yourTurn:
            tileStates = []
            yourTurnPhase = .watch
            syncYourTurnTray(for: .watch)
        case .wordPickVideo(let item):
            tileStates = Array(repeating: .rest, count: item.choices.count)
            navigationButton = .waiting("Choose an answer")
        case .watchChoose(let item), .translationChoose(let item):
            tileStates = Array(repeating: .rest, count: item.choices.count)
            navigationButton = .waiting("Choose an answer")
        case .signSequence(let item):
            tileStates = Array(repeating: .rest, count: item.choices.count)
            navigationButton = .waiting("Choose signs in order")
        case .phraseSlot(let item):
            tileStates = Array(repeating: .rest, count: item.choices.count)
            navigationButton = .waiting("Choose an answer")
        case .fillSlot(let item):
            tileStates = Array(repeating: .rest, count: item.choices.count)
            navigationButton = .waiting("Choose an answer")
        case .matchPairs(let item):
            tileStates = []
            matchBoardWordIds = item.wordIds
            matchRemainingWordIds = item.wordIds
            matchResolvedWordIds = []
            selectedMatchTranslationWordId = nil
            rebuildMatchPairColumnOrders()
            navigationButton = .waiting("Choose an answer")
            selectFirstAvailableMatchVideo()
        }

        loadCurrentVideoIfReady()
        store.preloadLessonMedia(
            lesson: lesson,
            unit: unit,
            priorityStepIndex: session.currentIndex
        )
    }

    private func recordMistakeMemory(wordIds: [String]) {
        guard !isRedrillPhase else { return }
        for wordId in wordIds {
            store.recordStoneMiss(
                unitId: unit.id,
                wordId: wordId,
                stoneSortOrder: lesson.sortOrder
            )
        }
    }

    private func replayVideoAfterWrongTap(choiceCount: Int) {
        if choiceCount > 2 {
            playerController.setSlowMotion(true)
        } else {
            playerController.setSlowMotion(false)
        }
        playerController.resumeLooping()
    }

    private func tappedChoice(index: Int,
                              picked: String,
                              answerWordId: String,
                              choices: [String],
                              answerLabel: String? = nil) {
        guard !lockTaps else { return }

        if picked == answerWordId {
            lockTaps = true
            redrillResetWorkItem?.cancel()

            if isRedrillPhase {
                recordGradedCorrect()
            } else {
                let wasForceRetap = tileStates.contains(.wrong)
                if !wasForceRetap {
                    recordGradedCorrect()
                    queueStreakMilestoneIfNeeded()
                }
            }
            tileStates[index] = .correct
            Haptics.correct()
            LessonSounds.play(.correct)
            navigationButton = .correct(
                headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
                actionTitle: nextContinueActionTitle()
            )
            correctFeedbackIndex += 1
        } else {
            if isRedrillPhase {
                handleRedrillWrongChoice(
                    at: index,
                    choiceCount: choices.count
                )
            } else {
                lockTaps = true
                session.recordWrong(wordId: answerWordId)
                if let current = session.current {
                    missedSteps.append(current)
                }
                recordMistakeMemory(wordIds: [answerWordId])
                Haptics.wrong()
                LessonSounds.play(.wrong)
                revealWrong(index: index, answerWordId: answerWordId, choices: choices)
                navigationButton = .wrong(
                    headline: ASLRedrillCopy.firstPassWrongHeadline(index: wrongFeedbackIndex),
                    answer: answerLabel ?? wordText(for: answerWordId),
                    actionTitle: nextContinueActionTitle()
                )
                wrongFeedbackIndex += 1
                // 4-choice mistakes replay slowly (except memory countdown, 1× only).
                replayVideoAfterWrongTap(choiceCount: choices.count)
            }
        }
    }

    private func selectChoice(index: Int, picked: String) {
        guard !lockTaps else { return }
        redrillResetWorkItem?.cancel()
        if tileStates.indices.contains(index), tileStates[index] == .wrong {
            tileStates[index] = .rest
        }
        selectedChoiceIndex = index
        selectedChoiceWordId = picked
        navigationButton = .checkAnswer
    }

    /// Review Mode: flash wrong, show a soft retry hint, then clear so they can
    /// re-pick the same missed question.
    private func handleRedrillWrongChoice(at index: Int, choiceCount: Int) {
        if tileStates.count != choiceCount {
            tileStates = Array(repeating: .rest, count: choiceCount)
        }
        tileStates[index] = .wrong
        Haptics.wrong()
        LessonSounds.play(.wrong)
        replayVideoAfterWrongTap(choiceCount: choiceCount)

        navigationButton = .waiting(ASLRedrillCopy.polishRetryHint)

        redrillResetWorkItem?.cancel()
        let work = DispatchWorkItem {
            for i in tileStates.indices where tileStates[i] == .wrong {
                tileStates[i] = .rest
            }
            selectedChoiceIndex = nil
            selectedChoiceWordId = nil
            navigationButton = .waiting(ASLRedrillCopy.polishPromptHint)
        }
        redrillResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func checkSelectedChoice() {
        guard let step = session.current else { return }

        switch step {
        case .signSequence(let item):
            checkSignSequence(item: item)
        case .watchChoose(let item), .translationChoose(let item):
            guard let selectedChoiceIndex, let selectedChoiceWordId else { return }
            tappedChoice(
                index: selectedChoiceIndex,
                picked: selectedChoiceWordId,
                answerWordId: item.answerWordId,
                choices: item.choices
            )
        case .wordPickVideo(let item):
            guard let selectedChoiceWordId else { return }
            tappedChoice(
                index: selectedChoiceIndex ?? 0,
                picked: selectedChoiceWordId,
                answerWordId: item.answerWordId,
                choices: item.choices
            )
        case .fillSlot(let item):
            guard let selectedChoiceIndex, let selectedChoiceWordId else { return }
            tappedChoice(
                index: selectedChoiceIndex,
                picked: selectedChoiceWordId,
                answerWordId: item.answerWordId,
                choices: item.choices
            )
        case .phraseSlot(let item):
            guard let selectedChoiceIndex, let selectedChoiceWordId else { return }
            tappedChoice(
                index: selectedChoiceIndex,
                picked: selectedChoiceWordId,
                answerWordId: item.answerWordId,
                choices: item.choices
            )
        case .teach, .yourTurn, .aslTip, .matchPairs:
            return
        }
    }

    private func appendSignSequencePick(_ picked: String, item: SignSequenceItem) {
        guard !lockTaps, signSequenceFilled.count < item.sequenceWordIds.count else { return }
        signSequenceFilled.append(picked)
        Haptics.tap()
        if signSequenceFilled.count == item.sequenceWordIds.count {
            navigationButton = .checkAnswer
        }
    }

    private func undoSignSequenceSlot(at index: Int) {
        guard !lockTaps, index == signSequenceFilled.count - 1, !signSequenceFilled.isEmpty else { return }
        signSequenceFilled.removeLast()
        Haptics.tap()
        navigationButton = .waiting("Choose signs in order")
    }

    private func queueStreakMilestoneIfNeeded() {
        let streak = session.currentStreak
        guard ASLStarEconomy.inLessonStreakCelebrationThresholds.contains(streak) else { return }
        pendingStreakCount = streak
    }

    private func checkSignSequence(item: SignSequenceItem) {
        if signSequenceFilled == item.sequenceWordIds {
            lockTaps = true
            recordGradedCorrect()
            if !isRedrillPhase {
                queueStreakMilestoneIfNeeded()
            }
            Haptics.correct()
            LessonSounds.play(.correct)
            navigationButton = .correct(
                headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
                actionTitle: nextContinueActionTitle()
            )
            correctFeedbackIndex += 1
        } else if isRedrillPhase {
            Haptics.wrong()
            LessonSounds.play(.wrong)
            signSequenceFilled = []
            navigationButton = .waiting(ASLRedrillCopy.polishRetryHint)

            redrillResetWorkItem?.cancel()
            let work = DispatchWorkItem {
                navigationButton = .waiting("Choose signs in order")
            }
            redrillResetWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
        } else {
            lockTaps = true
            session.recordWrong(wordId: item.phraseWordId)
            if let current = session.current {
                missedSteps.append(current)
            }
            recordMistakeMemory(wordIds: [item.phraseWordId])
            Haptics.wrong()
            LessonSounds.play(.wrong)
            signSequenceFilled = []
            navigationButton = .wrong(
                headline: ASLRedrillCopy.firstPassWrongHeadline(index: wrongFeedbackIndex),
                answer: wordText(for: item.phraseWordId),
                actionTitle: nextContinueActionTitle()
            )
            wrongFeedbackIndex += 1
        }
    }

    private func firstAvailableMatchPlayWordId() -> String? {
        matchPlayColumnOrder.first { matchRemainingWordIds.contains($0) }
    }

    private func selectFirstAvailableMatchVideo() {
        guard let wordId = firstAvailableMatchPlayWordId() else { return }
        selectedMatchVideoWordId = wordId
        ensureVideo(for: wordId)
    }

    private func maintainActiveMatchVideo() {
        if let selected = selectedMatchVideoWordId, matchRemainingWordIds.contains(selected) {
            ensureVideo(for: selected)
            return
        }
        selectFirstAvailableMatchVideo()
    }

    private func matchPairPlayFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch matchPairFlash {
        case .wrong(let videoWordId, _):
            return (videoWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }

    private func matchPairWordFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch matchPairFlash {
        case .wrong(_, let translationWordId):
            return (translationWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }

    private func cancelMatchPairFeedbackWorkItem() {
        matchPairFeedbackWorkItem?.cancel()
        matchPairFeedbackWorkItem = nil
    }

    /// Independent shuffles so sign (play) and translation columns rarely align
    /// on the same row; avoids identical column order when there are 2+ pairs.
    private func rebuildMatchPairColumnOrders() {
        let ids = matchBoardWordIds
        guard !ids.isEmpty else {
            matchPlayColumnOrder = []
            matchTranslationColumnOrder = []
            return
        }
        var rng = SystemRandomNumberGenerator()
        var play = ids
        play.shuffle(using: &rng)
        var translation = ids
        translation.shuffle(using: &rng)
        if ids.count > 1 {
            var attempts = 0
            while play == translation, attempts < 20 {
                translation.shuffle(using: &rng)
                attempts += 1
            }
        }
        matchPlayColumnOrder = play
        matchTranslationColumnOrder = translation
    }

    private func selectMatchVideo(_ wordId: String) {
        guard matchRemainingWordIds.contains(wordId), !lockTaps else { return }
        selectedMatchVideoWordId = wordId
        Haptics.tap()
        ensureVideo(for: wordId)
        tryResolveMatchPairIfReady()
    }

    private func selectMatchTranslation(_ wordId: String) {
        guard matchRemainingWordIds.contains(wordId), !lockTaps else { return }
        selectedMatchTranslationWordId = wordId
        Haptics.tap()
        tryResolveMatchPairIfReady()
    }

    private func tryResolveMatchPairIfReady() {
        guard case .matchPairs = session.current else { return }
        guard matchPairFlash == nil else { return }
        guard let videoWord = selectedMatchVideoWordId,
              let translationWord = selectedMatchTranslationWordId else { return }

        cancelMatchPairFeedbackWorkItem()

        if videoWord == translationWord {
            let matchedWordId = videoWord
            let isLastPair = matchRemainingWordIds.count == 1

            MatchPairResolution.scheduleCorrectMatch(
                matchedWordId: matchedWordId,
                isLastPair: isLastPair,
                setFlash: { matchPairFlash = $0 },
                setLockTaps: { lockTaps = $0 },
                clearSelection: {
                    selectedMatchTranslationWordId = nil
                },
                removePair: {
                    matchResolvedWordIds.insert(matchedWordId)
                    matchRemainingWordIds.removeAll { $0 == matchedWordId }
                },
                onRoundContinues: {
                    selectFirstAvailableMatchVideo()
                },
                onRoundComplete: {
                    if !matchMissRecorded {
                        recordGradedCorrect()
                        if !isRedrillPhase {
                            queueStreakMilestoneIfNeeded()
                        }
                    }
                    lockTaps = true
                    navigationButton = .correct(
                        headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
                        actionTitle: nextContinueActionTitle()
                    )
                    correctFeedbackIndex += 1
                },
                storeWorkItem: { matchPairFeedbackWorkItem = $0 }
            )
        } else {
            guard let current = session.current else { return }

            if !isRedrillPhase && !matchMissRecorded {
                session.recordWrong(wordId: videoWord)
                missedSteps.append(current)
                recordMistakeMemory(wordIds: [videoWord])
                matchMissRecorded = true
            }
            Haptics.wrong()
            LessonSounds.play(.wrong)

            lockTaps = true
            matchPairFlash = .wrong(videoWordId: videoWord, translationWordId: translationWord)

            let work = DispatchWorkItem {
                matchPairFlash = nil
                selectedMatchTranslationWordId = nil
                lockTaps = false
                maintainActiveMatchVideo()
            }
            matchPairFeedbackWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + ASLMatchPairFeedback.wrongFlashDuration,
                execute: work
            )
        }
    }

    private func revealWrong(index: Int, answerWordId: String, choices: [String]) {
        for i in tileStates.indices {
            if i == index {
                tileStates[i] = .wrong
            } else if choices[i] == answerWordId {
                tileStates[i] = .correctGlow
            } else {
                tileStates[i] = .dimmed
            }
        }
    }

    private func advance() {
        if case .teach(let item) = session.current, !item.isPracticeReplay {
            store.markWordIntroducedOnPath(item.wordId)
        }
        session.advance()
        if !isRedrillPhase {
            // During the initial pass we persist intermediate progress but
            // *never* mark the lesson complete here — that's `finishModule`'s
            // job after redrill (if any) has been cleared.
            store.updateLessonProgress(
                lessonId: lesson.id,
                currentIndex: session.currentIndex,
                totalSteps: session.total,
                isComplete: false
            )
        }
        if session.isComplete {
            finishModule()
        }
    }

    private func syncYourTurnTray(for phase: YourTurnPhase) {
        guard case .yourTurn = session.current else { return }
        switch phase {
        case .watch:
            navigationButton = .ready("Record now")
        case .review:
            navigationButton = .ready("Done")
        case .recording:
            break
        }
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        if case .yourTurn = session.current {
            switch yourTurnPhase {
            case .watch:
                yourTurnPhase = .recording
                return
            case .recording:
                return
            case .review:
                break
            }
        }

        if case .checkAnswer = navigationButton {
            checkSelectedChoice()
            return
        }

        if case .ready = navigationButton {
            Haptics.correct()
            LessonSounds.play(.correct)
        }

        if let streakCount = pendingStreakCount {
            pendingStreakCount = nil
            streakCelebrationCount = streakCount
            showStreakCelebration = true
            return
        }

        advance()
    }

    private func dismissStreakCelebration() {
        guard showStreakCelebration else { return }
        store.awardStreakMilestone(lessonId: lesson.id, streak: streakCelebrationCount)
        showStreakCelebration = false
        advance()
    }

    private static let continueActionTitles = ["Continue", "Next question"]

    private func nextContinueActionTitle() -> String {
        let title = Self.continueActionTitles[continueActionTitleIndex % Self.continueActionTitles.count]
        continueActionTitleIndex += 1
        return title
    }

    private func finishModule() {
        guard !showStoneCelebration && !showUnitCelebration && !showRedrillIntro && !showPhaseReviewComplete else { return }

        if !isRedrillPhase && !missedSteps.isEmpty {
            let missedWordIds = Set(missedSteps.flatMap(\.gradedAnswerWordIds))
            let missedCount = missedWordIds.count
            let gradedTotal = max(firstPassGradedCount, 1)
            let accuracy = 1.0 - Double(missedCount) / Double(gradedTotal)
            let needsRedrill = missedCount >= 2 || accuracy < 0.80

            if needsRedrill {
                firstPassCompleted = max(firstPassStepCount, session.total)
                pendingReviewStepCount = max(missedSteps.count, 1)
                withAnimation(.easeIn(duration: 0.2)) { showRedrillIntro = true }
                return
            }
        }

        // Either the user nailed the initial pass, cleared redrill, or had a
        // single miss below the polish threshold. Mark complete and celebrate.
        let totalSteps = max(session.total, 1)
        let firstPassPerfect = !isRedrillPhase && missedSteps.isEmpty
        store.updateLessonProgress(
            lessonId: lesson.id,
            currentIndex: totalSteps,
            totalSteps: totalSteps,
            isComplete: true
        )

        let isLastStone = lesson.sortOrder >= unit.lessonCount
        let finishesUnit = unit.isPhaseReview || isLastStone
        stoneCompletionAward = store.awardStoneCompletion(
            lesson: lesson,
            unit: unit,
            sessionBestStreak: stoneCelebrationBestStreak,
            firstPassPerfect: firstPassPerfect,
            finishesUnit: finishesUnit
        )

        if unit.isPhaseReview {
            withAnimation(.easeIn(duration: 0.25)) { showPhaseReviewComplete = true }
            return
        }

        if isLastStone {
            withAnimation(.easeIn(duration: 0.25)) { showUnitCelebration = true }
        } else {
            withAnimation(.easeIn(duration: 0.2)) { showStoneCelebration = true }
        }
    }

    private func beginPhaseReview() {
        withAnimation(.easeOut(duration: 0.2)) { showPhaseReviewIntro = false }
        startStep()
    }

    private func maybeShowPhaseReviewRoundBanner(for step: ModulePlayStep) {
        guard unit.isPhaseReview else { return }
        let round = PhaseReviewRound.round(for: step)
        guard round != lastShownPhaseReviewRound else { return }
        lastShownPhaseReviewRound = round
        showPhaseReviewRoundBanner(round)
    }

    private func showPhaseReviewRoundBanner(_ round: PhaseReviewRound) {
        cancelPhaseReviewRoundBanner()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            phaseReviewRoundBanner = round
        }
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                phaseReviewRoundBanner = nil
            }
        }
        phaseReviewRoundBannerWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func cancelPhaseReviewRoundBanner() {
        phaseReviewRoundBannerWorkItem?.cancel()
        phaseReviewRoundBannerWorkItem = nil
        phaseReviewRoundBanner = nil
    }

    private func startRedrill() {
        guard !missedSteps.isEmpty else { return }
        isRedrillPhase = true
        showRedrillIntro = false
        session.reload(with: missedSteps)
        startStep()
    }

    private func cancelModulePickReveal() {
        modulePickRevealWorkItems.forEach { $0.cancel() }
        modulePickRevealWorkItems.removeAll()
        modulePickRevealCountdown = nil
    }

    /// 3 → 2 → 1 on-screen, then runs `onReveal` on `watchThenPick`.
    private func startModulePickReveal(seconds: Int, onReveal: @escaping () -> Void) {
        cancelModulePickReveal()
        guard seconds > 0 else {
            onReveal()
            return
        }

        modulePickRevealCountdown = seconds

        for tick in 1..<seconds {
            let next = seconds - tick
            let tickWork = DispatchWorkItem {
                modulePickRevealCountdown = next
                Haptics.tap()
            }
            modulePickRevealWorkItems.append(tickWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(tick), execute: tickWork)
        }

        let revealWork = DispatchWorkItem {
            modulePickRevealCountdown = nil
            onReveal()
        }
        modulePickRevealWorkItems.append(revealWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds), execute: revealWork)
    }

    @ViewBuilder
    private func modulePickCountdownBanner(minHeight: CGFloat) -> some View {
        if let n = modulePickRevealCountdown {
            Text("\(n)")
                .aslStyle(.celebrationStat)
                .foregroundStyle(Brand.textPrimary)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: n)
        }
    }

    // MARK: - Helpers

    private var paletteColor: Color { LessonPalette.color(for: unit) }
    private var paletteShadowColor: Color { LessonPalette.shadow(for: unit) }

    private var nextPlayableUnit: ASLUnit? {
        store.nextPlayableUnit(after: unit)
    }

    private var nextUnitPaletteColor: Color {
        guard let nextPlayableUnit else { return paletteColor }
        return LessonPalette.color(for: nextPlayableUnit)
    }

    private var nextUnitPaletteShadowColor: Color {
        guard let nextPlayableUnit else { return paletteShadowColor }
        return LessonPalette.shadow(for: nextPlayableUnit)
    }

    private func continueAfterUnitCompletion() {
        if unit.id == "p1-u10" {
            store.queueSpellYourNamePractice(intent: .personalName)
        }

        guard let next = nextPlayableUnit else {
            dismissLesson()
            return
        }

        store.loadLessons(for: next)

        guard let nextLesson = firstLesson(in: next) else {
            store.queueAutoStartUnit(next.id)
            dismissLesson()
            return
        }

        handoffToNextUnitLesson(nextLesson, in: next)
    }

    private func handoffToNextUnitLesson(_ lesson: ASLLesson, in unit: ASLUnit) {
        let request = LessonEntryRevealRequest(
            fillColor: LessonPalette.color(for: unit),
            origin: lessonPortalHandoffOrigin(),
            lesson: lesson,
            unit: unit
        )

        // Pop the completed lesson before opening the next one. Updating
        // nextLessonRoute in place leaves a blank ModuleLessonView underneath
        // the portal because the finished stone has no active step to render.
        portalDismiss?()

        DispatchQueue.main.async {
            lessonEntryRevealCoordinator.begin(request: request, reduceMotion: reduceMotion)
            if reduceMotion {
                lessonEntryRevealCoordinator.sheetDidDismiss(reduceMotion: true)
            }
        }
    }

    private func firstLesson(in unit: ASLUnit) -> ASLLesson? {
        (store.lessonsByUnitId[unit.id] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .first
    }

    private func lessonPortalHandoffOrigin() -> CGPoint {
        let bounds = UIScreen.main.bounds
        let buttonCenterY = bounds.maxY
            - LessonActionTrayLayout.effectiveBottomPadding
            - (LessonActionTrayLayout.buttonHeight / 2)
        return CGPoint(x: bounds.midX, y: buttonCenterY)
    }

    private var fillSlotChipForeground: Color {
        guard selectedChoiceWordId != nil else { return paletteColor }
        switch navigationButton {
        case .correct:
            return Color.lessonCorrectText
        case .wrong:
            return Color.lessonWrongText
        default:
            return Brand.textPrimary
        }
    }

    private var fillSlotChipFill: Color {
        guard selectedChoiceWordId != nil else { return paletteColor.opacity(0.18) }
        switch navigationButton {
        case .correct:
            return Color.lessonCorrectPanel
        case .wrong:
            return Color.lessonErrorPanel
        default:
            return Color.white
        }
    }

    private var fillSlotChipBorder: Color {
        guard selectedChoiceWordId != nil else { return paletteColor.opacity(0.7) }
        switch navigationButton {
        case .correct:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        default:
            return paletteColor
        }
    }

    private var fillSlotChipBorderWidth: CGFloat {
        selectedChoiceWordId == nil ? 2 : 3
    }

    private static let fillSlotChipMinWidth: CGFloat = 72
    private static let fillSlotChipMinHeight: CGFloat = 38

    private var fillSlotChip: some View {
        ZStack {
            if let wordId = selectedChoiceWordId {
                Text(wordText(for: wordId))
                    .font(LessonQuestionLayout.chipFont)
                    .foregroundStyle(fillSlotChipForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 10)
            }
        }
        .frame(minWidth: Self.fillSlotChipMinWidth, minHeight: Self.fillSlotChipMinHeight)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(fillSlotChipFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(fillSlotChipBorder, lineWidth: fillSlotChipBorderWidth)
        )
        .transaction { $0.animation = nil }
    }

    private func signSequenceSlot(
        wordId: String?,
        phraseWordId: String,
        onUndo: @escaping () -> Void
    ) -> some View {
        ZStack {
            if let wordId {
                Text(wordText(for: wordId, phraseId: phraseWordId))
                    .font(LessonQuestionLayout.chipFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 8)
            }
        }
        .frame(minWidth: 56, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wordId == nil ? paletteColor.opacity(0.14) : paletteColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(paletteColor.opacity(wordId == nil ? 0.5 : 0.85), lineWidth: wordId == nil ? 2 : 2.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onUndo)
        .transaction { $0.animation = nil }
    }

    private var stepTransition: AnyTransition {
        .opacity
    }

    private func wordText(for wordId: String, phraseId: String? = nil) -> String {
        let catalog = store.wordsById[wordId]?.text ?? wordId
        if let phraseId {
            return ASLWordDisplay.phraseComponentTitle(
                wordId: wordId,
                phraseId: phraseId,
                catalogText: catalog
            )
        }
        return ASLWordDisplay.title(for: catalog)
    }

    private func loadCurrentVideoIfReady() {
        guard let wordId = currentVideoWordId else { return }
        ensureVideo(for: wordId)
    }

    private func ensureVideo(for wordId: String) {
        attachedVideoWordId = wordId
        guard store.hasPlayableVideo(for: wordId),
              !ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store),
              !ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) else {
            playerController.detach()
            return
        }
        if playerController.loadedWordId == wordId, playerController.isPlaybackReady {
            playerController.resumeLooping()
            return
        }
        Task {
            await store.ensureVideoAttached(to: playerController, wordId: wordId)
            guard attachedVideoWordId == wordId else { return }
            playerController.playAtNormalSpeed()
        }
    }

    private var currentVideoWordId: String? {
        guard let step = session.current else { return nil }
        switch step {
        case .teach(let item), .yourTurn(let item):
            return item.wordId
        case .aslTip(let item):
            return item.wordId
        case .watchChoose(let item), .translationChoose(let item):
            return item.answerWordId
        case .fillSlot(let item):
            return item.phraseWordId ?? item.answerWordId
        case .signSequence(let item):
            return item.phraseWordId
        case .phraseSlot(let item):
            return item.phraseWordId
        case .wordPickVideo, .matchPairs:
            return nil
        }
    }
}

// MARK: - Module play types

private enum VariedConfirmPickKind: CaseIterable {
    case translationChoose, wordPickVideo, watchChoose
}

enum ModulePlayStep: Identifiable {
    case teach(ModuleTeachItem)
    case wordPickVideo(WordPickVideoItem)
    case watchChoose(ModulePickItem)
    case translationChoose(ModulePickItem)
    case signSequence(SignSequenceItem)
    case phraseSlot(PhraseSlotItem)
    case fillSlot(FillGapPlayItem)
    case matchPairs(MatchPairsItem)
    case yourTurn(ModuleTeachItem)
    case aslTip(ASLTipItem)

    var id: UUID {
        switch self {
        case .teach(let item), .yourTurn(let item): return item.id
        case .wordPickVideo(let item): return item.id
        case .watchChoose(let item): return item.id
        case .translationChoose(let item): return item.id
        case .signSequence(let item): return item.id
        case .phraseSlot(let item): return item.id
        case .fillSlot(let item): return item.id
        case .matchPairs(let item): return item.id
        case .aslTip(let item): return item.id
        }
    }

    var isYourTurn: Bool {
        if case .yourTurn = self {
            return true
        }
        return false
    }

    /// Continue-only informational/active beats that are never graded.
    var isPassiveContinueStep: Bool {
        switch self {
        case .teach, .yourTurn, .aslTip:
            return true
        default:
            return false
        }
    }

    /// Steps where the learner picks an answer and receives correct/incorrect feedback.
    var isGradedQuestionStep: Bool {
        !isPassiveContinueStep
    }

    func coversPractice(for wordId: String) -> Bool {
        gradedAnswerWordIds.contains(wordId)
    }

    var gradedAnswerWordIds: [String] {
        switch self {
        case .watchChoose(let item), .translationChoose(let item):
            return [item.answerWordId]
        case .wordPickVideo(let item):
            return [item.answerWordId]
        case .fillSlot(let item):
            return [item.answerWordId]
        case .signSequence(let item):
            return [item.phraseWordId]
        case .phraseSlot(let item):
            return [item.answerWordId]
        case .matchPairs(let item):
            return item.wordIds
        case .teach(let item):
            return item.isPracticeReplay ? [item.wordId] : []
        case .yourTurn, .aslTip:
            return []
        }
    }
}

struct ASLTipItem: Identifiable {
    let id = UUID()
    let tipId: String
    let text: String
    /// Optional contextual sign/phrase video shown above the tip.
    let wordId: String?
}

struct ModuleTeachItem {
    let id = UUID()
    let wordId: String
    let title: String
    let prompt: String
    var isPracticeReplay: Bool = false
}

struct ModulePickItem {
    let id = UUID()
    let answerWordId: String
    let choices: [String]
    let prompt: String
}

struct WordPickVideoItem {
    let id = UUID()
    let answerWordId: String
    let choices: [String]
    let labels: [String]
    let prompt: String
}


struct SignSequenceItem {
    let id = UUID()
    let phraseWordId: String
    let sequenceWordIds: [String]
    let choices: [String]
    let prompt: String
}

struct PhraseSlotItem {
    let id = UUID()
    let phraseWordId: String
    let sequenceWordIds: [String]
    let slotIndex: Int
    let answerWordId: String
    let choices: [String]
    let prompt: String
}

struct FillGapPlayItem {
    let id = UUID()
    let before: String
    let after: String
    let answerWordId: String
    let choices: [String]
    let prompt: String
    let phraseWordId: String?
}

// MARK: - Composition

extension ModuleLessonView {
    static func buildPlaySteps(
        for lesson: ASLLesson,
        store: ASLDataStore,
        introducedSoFar seed: Set<String>? = nil
    ) -> [ModulePlayStep] {
        var generator = SeededRandomNumberGenerator(seed: StableSeed.fnv1a64(lesson.id))
        let steps = lesson.steps
        // Stone 1 always shows a teach screen before quizzing each new sign in this
        // lesson, even when path progress survived a stone reset or curriculum change.
        // Later stones skip re-teaching words already introduced on the path.
        let pathIntroduced = seed ?? store.introducedWordIdsOnPath
        var introducedSoFar = lesson.sortOrder == 1 ? Set<String>() : pathIntroduced
        var previousStepWasPassive = false
        let playSteps: [ModulePlayStep] = steps.enumerated().compactMap { stepIndex, step -> ModulePlayStep? in
            let answer = step.answerWordId ?? step.wordId

            func isNewWordIntroduction(for wordId: String?) -> Bool {
                guard let wordId, lesson.wordIds.contains(wordId) else { return false }
                if introducedSoFar.contains(wordId) { return false }
                introducedSoFar.insert(wordId)
                return true
            }

            func framedPrompt(_ kind: ModuleStepKind, wordId: String? = nil) -> String {
                ASLLessonPromptFraming.prompt(
                    for: kind,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    wordId: wordId,
                    wordLabel: wordId.map { ASLWordDisplay.title(for: $0) }
                )
            }

            func trackPassiveStep(_ step: ModulePlayStep) -> ModulePlayStep {
                previousStepWasPassive = isPassiveStep(step)
                return step
            }

            func introOrPickStep(
                answer: String,
                pick: () -> ModulePlayStep
            ) -> ModulePlayStep {
                if isNewWordIntroduction(for: answer) {
                    return trackPassiveStep(.teach(makeTeachItem(
                        wordId: answer,
                        lessonId: lesson.id,
                        stepIndex: stepIndex
                    )))
                }
                return trackPassiveStep(pick())
            }

            switch step.kind {
            case .teach:
                guard let wordId = step.wordId else { return nil }
                guard !introducedSoFar.contains(wordId) else { return nil }
                introducedSoFar.insert(wordId)
                return trackPassiveStep(.teach(makeTeachItem(
                    wordId: wordId,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    authoredTitle: step.title,
                    authoredPrompt: step.prompt
                )))
            case .watchPick2, .watchPick4, .sameDifferent, .meaningPick,
                 .watchThenPick, .fillGap, .selfSign, .speedBurst:
                return nil
            case .wordPickVideo:
                guard let answer else { return nil }
                return introOrPickStep(answer: answer) {
                    .wordPickVideo(makeWordPickVideoItem(
                        answer: answer,
                        lesson: lesson,
                        authoredDistractors: step.distractorWordIds,
                        prompt: framedPrompt(.wordPickVideo, wordId: answer),
                        generator: &generator
                    ))
                }
            case .watchChoose:
                guard let answer else { return nil }
                return introOrPickStep(answer: answer) {
                    .watchChoose(makePickItem(
                        answer: answer,
                        lesson: lesson,
                        authoredDistractors: step.distractorWordIds,
                        choiceCount: step.choiceCount ?? 2,
                        prompt: framedPrompt(.watchChoose, wordId: answer),
                        preferSemanticDistractors: true,
                        generator: &generator
                    ))
                }
            case .translationChoose:
                guard let answer else { return nil }
                return introOrPickStep(answer: answer) {
                    .translationChoose(makePickItem(
                        answer: answer,
                        lesson: lesson,
                        authoredDistractors: step.distractorWordIds,
                        choiceCount: step.choiceCount ?? 2,
                        prompt: framedPrompt(.translationChoose, wordId: answer),
                        preferSemanticDistractors: true,
                        generator: &generator
                    ))
                }
            case .signSequence:
                guard let phraseId = step.wordId else { return nil }
                let sequence = step.sequenceWordIds
                guard sequence.count >= 2 else { return nil }
                let item = makeSignSequenceItem(
                    phraseId: phraseId,
                    sequence: sequence,
                    lesson: lesson,
                    authoredDistractors: step.distractorWordIds,
                    prompt: framedPrompt(.signSequence),
                    generator: &generator
                )
                guard item.sequenceWordIds.count >= 2, item.choices.count >= 2 else { return nil }
                return trackPassiveStep(.signSequence(item))
            case .phraseSlot:
                guard let phraseId = step.wordId,
                      let answer = step.answerWordId,
                      let slotIndex = step.slotIndex else { return nil }
                let sequence = step.sequenceWordIds
                guard sequence.count >= 2,
                      slotIndex >= 0,
                      slotIndex < sequence.count,
                      sequence[slotIndex] == answer else { return nil }
                return trackPassiveStep(.phraseSlot(makePhraseSlotItem(
                    phraseId: phraseId,
                    sequence: sequence,
                    slotIndex: slotIndex,
                    answer: answer,
                    lesson: lesson,
                    authoredDistractors: step.distractorWordIds,
                    prompt: step.prompt.isEmpty
                        ? ASLLessonPromptFraming.prompt(for: .phraseSlot, lessonId: lesson.id, stepIndex: stepIndex)
                        : step.prompt,
                    generator: &generator
                )))
            case .fillSlot:
                guard let answer else { return nil }
                return introOrPickStep(answer: answer) {
                    .fillSlot(makeFillGapItem(
                        answer: answer,
                        step: step,
                        lesson: lesson,
                        prompt: framedPrompt(.fillSlot),
                        phraseWordId: step.wordId,
                        generator: &generator
                    ))
                }
            case .matchPairs:
                let authored = step.pairWordIds.isEmpty ? step.distractorWordIds : step.pairWordIds
                let words = makeMatchPairWords(authored: authored, answer: answer, lesson: lesson)
                guard words.count >= 2 else { return nil }
                return trackPassiveStep(.matchPairs(MatchPairsItem(
                    wordIds: words,
                    prompt: framedPrompt(.matchPairs)
                )))
            case .yourTurn:
                guard lesson.sortOrder <= 3 else { return nil }
                guard let wordId = step.wordId ?? step.answerWordId ?? lesson.wordIds.first else { return nil }
                return trackPassiveStep(.yourTurn(ModuleTeachItem(
                    wordId: wordId,
                    title: step.title,
                    prompt: step.prompt
                )))
            case .aslTip:
                let tipText = step.prompt.isEmpty ? step.title : step.prompt
                guard !tipText.isEmpty else { return nil }
                let resolved = ASLTipCatalog.resolve(
                    curriculumTipId: step.tipId,
                    curriculumText: tipText,
                    seenIds: store.seenASLTipIds
                )
                return trackPassiveStep(.aslTip(ASLTipItem(
                    tipId: resolved.id,
                    text: resolved.text,
                    wordId: step.wordId ?? resolved.wordId
                )))
            case .memoryCountdown:
                return nil
            case .unknown:
                return nil
            }
        }
        var result = playSteps
        applyMistakeCarryover(to: &result, lesson: lesson, store: store)
        result = separateAdjacentNewSignTeaches(in: result, lesson: lesson)
        result = replaceRedundantWatchChooseAfterTeach(in: result, lesson: lesson)
        result = capConsecutiveTeachConfirmPairs(in: result, lesson: lesson)
        result = collapseAdjacentSamePhraseVideoSteps(in: result)
        result = separateAdjacentMatchPairsSteps(in: result, lesson: lesson)
        result = respaceForVariety(result)
        result = collapseBackToBackPassiveSteps(in: result, lesson: lesson)
        result = filterMatchPairsToIntroducedWords(in: result, lesson: lesson, store: store)
        result = deduplicateTeachSteps(in: result)
        result = enforceTeachBeforeQuiz(in: result, lesson: lesson, pathIntroduced: pathIntroduced)
        result = deduplicateTeachSteps(in: result)
        result = enforceNoAdjacentSameGradedAnswer(in: result, lesson: lesson)
        return result
    }

    /// Never resume mid-stone on a quiz whose answer has not had a teach screen
    /// earlier in this lesson (e.g. after a curriculum shrink or stale step index).
    static func safeResumeStepIndex(
        saved: Int,
        steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> Int {
        guard saved > 0, steps.indices.contains(saved) else { return max(0, saved) }

        var seenTeach = Set<String>()
        for index in 0..<saved {
            if case .teach(let item) = steps[index], !item.isPracticeReplay {
                seenTeach.insert(item.wordId)
            }
        }

        guard lesson.sortOrder == 1,
              let answer = pickAnswerWordId(for: steps[saved]),
              isWordPickStep(steps[saved]),
              lesson.wordIds.contains(answer),
              !seenTeach.contains(answer) else {
            return saved
        }

        for (index, step) in steps.enumerated() where index < saved {
            if case .teach(let item) = step,
               !item.isPracticeReplay,
               item.wordId == answer {
                return index
            }
        }

        return 0
    }

    /// Drops repeat teach screens for the same word within one lesson play queue.
    private static func deduplicateTeachSteps(in steps: [ModulePlayStep]) -> [ModulePlayStep] {
        var seen = Set<String>()
        var result: [ModulePlayStep] = []
        for step in steps {
            if case .teach(let item) = step, !item.isPracticeReplay {
                guard !seen.contains(item.wordId) else { continue }
                seen.insert(item.wordId)
            }
            result.append(step)
        }
        return result
    }

    /// Guarantees every stone-vocabulary quiz is preceded by a teach screen in
    /// this lesson flow (Stone 1 always re-teaches; later stones honor path intros).
    private static func enforceTeachBeforeQuiz(
        in steps: [ModulePlayStep],
        lesson: ASLLesson,
        pathIntroduced: Set<String>
    ) -> [ModulePlayStep] {
        var seenTeachInLesson = Set<String>()
        var result: [ModulePlayStep] = []

        for step in steps {
            if case .teach(let item) = step, !item.isPracticeReplay {
                seenTeachInLesson.insert(item.wordId)
                result.append(step)
                continue
            }

            if let answer = pickAnswerWordId(for: step),
               isWordPickStep(step),
               lesson.wordIds.contains(answer),
               !ASLPhraseIds.contains(answer),
               !seenTeachInLesson.contains(answer) {
                let skipTeach = lesson.sortOrder > 1 && pathIntroduced.contains(answer)
                if !skipTeach {
                    result.append(.teach(makeTeachItem(
                        wordId: answer,
                        lessonId: lesson.id,
                        stepIndex: result.count
                    )))
                    seenTeachInLesson.insert(answer)
                }
            }

            result.append(step)
        }

        return result
    }

    /// Word ids shown on a teach / new-sign introduction screen in a play queue.
    static func introducedWordIds(in steps: [ModulePlayStep]) -> Set<String> {
        var ids = Set<String>()
        for step in steps {
            if case .teach(let item) = step, !item.isPracticeReplay {
                ids.insert(item.wordId)
            }
        }
        return ids
    }

    /// Match boards only include words the learner has been taught on a prior teach
    /// screen in this stone or on a completed earlier stone.
    private static func filterMatchPairsToIntroducedWords(
        in steps: [ModulePlayStep],
        lesson: ASLLesson,
        store: ASLDataStore
    ) -> [ModulePlayStep] {
        guard !steps.isEmpty else { return steps }

        var introducedSoFar = store.introducedWordIdsOnPath
        var result: [ModulePlayStep] = []
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":match-filter")
        )

        for step in steps {
            switch step {
            case .teach(let item) where !item.isPracticeReplay:
                introducedSoFar.insert(item.wordId)
                result.append(step)

            case .matchPairs(let item):
                var wordIds = item.wordIds.filter {
                    introducedSoFar.contains($0) && !ASLPhraseIds.contains($0)
                }
                if wordIds.count < 2 {
                    let pool = introducedSoFar
                        .filter { !ASLPhraseIds.contains($0) && !wordIds.contains($0) }
                        .sorted()
                    for word in pool {
                        wordIds.append(word)
                        if wordIds.count >= 4 { break }
                    }
                }
                wordIds = Array(wordIds.prefix(4))
                if wordIds.count >= 2 {
                    result.append(.matchPairs(MatchPairsItem(wordIds: wordIds, prompt: item.prompt)))
                } else if let fallback = introducedSoFar.first(where: { !ASLPhraseIds.contains($0) }) {
                    result.append(
                        variedConfirmPick(
                            for: fallback,
                            lesson: lesson,
                            stepIndex: result.count,
                            preferNonWatchChoose: true,
                            generator: &generator
                        )
                    )
                }

            default:
                result.append(step)
            }
        }

        return result
    }

    private static func trailingNewSignTeachCount(in steps: [ModulePlayStep]) -> Int {
        var count = 0
        for step in steps.reversed() {
            guard case .teach(let item) = step, !item.isPracticeReplay else { break }
            count += 1
        }
        return count
    }

    /// Never show two new-sign teach screens back-to-back; insert a confirm between.
    private static func separateAdjacentNewSignTeaches(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result: [ModulePlayStep] = []
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":teach-spacing")
        )

        for step in steps {
            if let last = result.last,
               case .teach(let prior) = last, !prior.isPracticeReplay,
               case .teach(let next) = step, !next.isPracticeReplay,
               prior.wordId != next.wordId,
               trailingNewSignTeachCount(in: result) >= 1 {
                result.append(
                    introConfirmPick(
                        for: prior.wordId,
                        lesson: lesson,
                        stepIndex: result.count,
                        generator: &generator
                    )
                )
            }
            result.append(step)
        }

        return result
    }

    private static func isTeachIntroConfirmPair(_ prev: ModulePlayStep, _ next: ModulePlayStep) -> Bool {
        guard case .teach(let item) = prev, !item.isPracticeReplay else { return false }
        switch next {
        case .watchChoose(let pick), .translationChoose(let pick):
            return pick.answerWordId == item.wordId
        case .wordPickVideo(let pick):
            return pick.answerWordId == item.wordId
        default:
            return false
        }
    }

    /// Cap teach → intro-confirm pairs (stone 1: one; later stones: two); insert variety before another.
    private static func capConsecutiveTeachConfirmPairs(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result: [ModulePlayStep] = []
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":teach-confirm-cap")
        )
        let maxPairs = 1
        var streak = 0
        var index = 0

        while index < steps.count {
            let step = steps[index]
            if index + 1 < steps.count,
               isTeachIntroConfirmPair(step, steps[index + 1]) {
                if streak >= maxPairs, case .teach(let prior) = step {
                    result.append(
                        variedConfirmPick(
                            for: prior.wordId,
                            lesson: lesson,
                            stepIndex: result.count,
                            preferNonWatchChoose: true,
                            generator: &generator
                        )
                    )
                    streak = 0
                }
                result.append(step)
                result.append(steps[index + 1])
                streak += 1
                index += 2
                continue
            }
            if !isPassiveStep(step) {
                streak = 0
            }
            result.append(step)
            index += 1
        }

        return result
    }

    /// After a new-sign teach, the next step should stay a watchChoose confirm
    /// with a consistent recognition headline (not wordPickVideo templates).
    private static func replaceRedundantWatchChooseAfterTeach(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result: [ModulePlayStep] = []
        var index = 0

        while index < steps.count {
            let step = steps[index]
            if case .teach(let item) = step, !item.isPracticeReplay,
               index + 1 < steps.count,
               case .watchChoose(let pick) = steps[index + 1],
               pick.answerWordId == item.wordId {
                result.append(step)
                if lesson.sortOrder != 1 {
                    let confirmPrompt = ASLPhraseIds.contains(item.wordId)
                        ? "What phrase is this?"
                        : "What sign is this?"
                    result.append(.watchChoose(ModulePickItem(
                        answerWordId: pick.answerWordId,
                        choices: pick.choices,
                        prompt: confirmPrompt
                    )))
                } else {
                    result.append(steps[index + 1])
                }
                index += 2
                continue
            }
            result.append(step)
            index += 1
        }

        return result
    }

    private static func isTwoChoiceWordPick(_ step: ModulePlayStep, wordId: String) -> Bool {
        switch step {
        case .watchChoose(let item):
            return item.answerWordId == wordId && item.choices.count == 2
        default:
            return false
        }
    }

    /// Continue-only beats (teach, self-sign) where the learner does not pick an answer.
    private static func isPassiveStep(_ step: ModulePlayStep) -> Bool {
        switch step {
        case .teach, .yourTurn, .aslTip:
            return true
        default:
            return false
        }
    }

    /// Break up back-to-back passive pages without removing teach intros.
    private static func collapseBackToBackPassiveSteps(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result: [ModulePlayStep] = []
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":passive-fix")
        )

        for step in steps {
            if let last = result.last, isPassiveStep(last), isPassiveStep(step),
               case .teach(let first) = last, case .teach = step,
               trailingNewSignTeachCount(in: result) >= 1 {
                result.append(
                    introConfirmPick(
                        for: first.wordId,
                        lesson: lesson,
                        stepIndex: result.count,
                        generator: &generator
                    )
                )
            }
            result.append(step)
        }

        return result
    }

    /// Recognition pick right after a new-sign intro — answer is always the new sign.
    private static func introConfirmPick<G: RandomNumberGenerator>(
        for wordId: String,
        lesson: ASLLesson,
        stepIndex: Int,
        generator: inout G
    ) -> ModulePlayStep {
        let distractors = authoredDistractors(for: wordId, in: lesson)
        if ASLPhraseIds.contains(wordId) {
            return .translationChoose(makePickItem(
                answer: wordId,
                lesson: lesson,
                authoredDistractors: distractors,
                choiceCount: 2,
                prompt: ASLLessonPromptFraming.prompt(
                    for: .translationChoose,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    wordId: wordId
                ),
                generator: &generator
            ))
        }
        return .watchChoose(makePickItem(
            answer: wordId,
            lesson: lesson,
            authoredDistractors: distractors,
            choiceCount: 2,
            prompt: "What sign is this?",
            generator: &generator
        ))
    }

    private static func variedConfirmPick<G: RandomNumberGenerator>(
        for wordId: String,
        lesson: ASLLesson,
        stepIndex: Int,
        preferNonWatchChoose: Bool = false,
        generator: inout G
    ) -> ModulePlayStep {
        var kinds: [VariedConfirmPickKind] = ASLPhraseIds.contains(wordId)
            ? [.translationChoose, .watchChoose]
            : VariedConfirmPickKind.allCases
        let slot = stepIndex + Int(StableSeed.fnv1a64(lesson.id + ":" + wordId) % 997)
        var pick = kinds[slot % kinds.count]
        if preferNonWatchChoose, pick == .watchChoose, kinds.count > 1 {
            pick = kinds[(slot + 1) % kinds.count]
        }

        let distractors = authoredDistractors(for: wordId, in: lesson)
        switch pick {
        case .translationChoose:
            return .translationChoose(makePickItem(
                answer: wordId,
                lesson: lesson,
                authoredDistractors: distractors,
                choiceCount: 2,
                prompt: ASLLessonPromptFraming.prompt(
                    for: .translationChoose,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    wordId: wordId
                ),
                generator: &generator
            ))
        case .wordPickVideo:
            return .wordPickVideo(makeWordPickVideoItem(
                answer: wordId,
                lesson: lesson,
                authoredDistractors: distractors,
                prompt: ASLLessonPromptFraming.prompt(
                    for: .wordPickVideo,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    wordId: wordId,
                    wordLabel: ASLWordDisplay.title(for: wordId)
                ),
                generator: &generator
            ))
        case .watchChoose:
            return .watchChoose(makePickItem(
                answer: wordId,
                lesson: lesson,
                authoredDistractors: distractors,
                choiceCount: 2,
                prompt: ASLLessonPromptFraming.prompt(
                    for: .watchChoose,
                    lessonId: lesson.id,
                    stepIndex: stepIndex,
                    wordId: wordId
                ),
                generator: &generator
            ))
        }
    }

    /// Curriculum-authored wrong answers for a word, falling back to the stone vocabulary.
    private static func authoredDistractors(for wordId: String, in lesson: ASLLesson) -> [String] {
        let phraseAnswer = ASLPhraseIds.contains(wordId)
        for step in lesson.steps {
            let answer = step.answerWordId ?? step.wordId
            guard answer == wordId else { continue }
            var distractors = step.distractorWordIds.filter { $0 != wordId }
            if phraseAnswer {
                distractors = distractors.filter { ASLPhraseIds.contains($0) }
            }
            if !distractors.isEmpty { return distractors }
        }
        return choicePool(for: wordId, in: lesson).filter { $0 != wordId }
    }

    /// True when the step re-quizzes vocabulary learned on a prior stone or unit.
    static func showsSignRefresherEyebrow(
        for step: ModulePlayStep,
        lesson: ASLLesson,
        unit: ASLUnit,
        isRedrillPhase: Bool,
        pathIntroducedAtLessonStart: Set<String>,
        stepIndex: Int,
        playSteps: [ModulePlayStep]
    ) -> Bool {
        guard !isRedrillPhase else { return false }
        guard lesson.sortOrder != 3 else { return false }
        guard showsRefresherEyebrow(for: step) else { return false }

        if unit.isPhaseReview {
            return true
        }

        let reviewWordIds = refresherWordIds(for: step)
        guard !reviewWordIds.isEmpty else { return false }

        guard reviewWordIds.allSatisfy({ pathIntroducedAtLessonStart.contains($0) }) else {
            return false
        }

        return !reviewWordIds.contains {
            wasTaughtEarlierInLesson(
                wordId: $0,
                playSteps: playSteps,
                beforeIndex: stepIndex
            )
        }
    }

    private static func showsRefresherEyebrow(for step: ModulePlayStep) -> Bool {
        switch step {
        case .teach, .yourTurn, .aslTip:
            return false
        default:
            return true
        }
    }

    private static func refresherWordIds(for step: ModulePlayStep) -> [String] {
        switch step {
        case .matchPairs(let item):
            return item.wordIds
        case .signSequence(let item):
            return [item.phraseWordId]
        case .phraseSlot(let item):
            return [item.phraseWordId]
        default:
            guard let wordId = pickAnswerWordId(for: step) else { return [] }
            return [wordId]
        }
    }

    private static func wasTaughtEarlierInLesson(
        wordId: String,
        playSteps: [ModulePlayStep],
        beforeIndex: Int
    ) -> Bool {
        guard beforeIndex > 0 else { return false }
        for index in 0..<min(beforeIndex, playSteps.count) {
            if case .teach(let item) = playSteps[index],
               !item.isPracticeReplay,
               item.wordId == wordId {
                return true
            }
        }
        return false
    }

    private static let legacySignRefresherPrompts: Set<String> = [
        "Quick warm-up — you know this one.",
        "Let's start easy.",
        "Warm up with a sign you know.",
        "Let's revisit this one.",
    ]

    static func signRefresherExerciseTitle(
        for step: ModulePlayStep?,
        fallback: String,
        lessonId: String,
        stepIndex: Int,
        wordLabel: (String) -> String
    ) -> String {
        guard let step else { return fallback }
        if let framed = framedPrompt(for: step, lessonId: lessonId, stepIndex: stepIndex, wordLabel: wordLabel),
           !framed.isEmpty {
            return framed
        }
        return legacySignRefresherPrompts.contains(fallback) ? "Choose the correct sign." : fallback
    }

    private static func framedPrompt(
        for step: ModulePlayStep,
        lessonId: String,
        stepIndex: Int,
        wordLabel: (String) -> String
    ) -> String? {
        switch step {
        case .watchChoose(let item):
            return ASLLessonPromptFraming.prompt(
                for: .watchChoose,
                lessonId: lessonId,
                stepIndex: stepIndex,
                wordId: item.answerWordId
            )
        case .translationChoose(let item):
            return ASLLessonPromptFraming.prompt(
                for: .translationChoose,
                lessonId: lessonId,
                stepIndex: stepIndex,
                wordId: item.answerWordId
            )
        case .wordPickVideo(let item):
            return ASLLessonPromptFraming.prompt(
                for: .wordPickVideo,
                lessonId: lessonId,
                stepIndex: stepIndex,
                wordId: item.answerWordId,
                wordLabel: wordLabel(item.answerWordId)
            )
        case .fillSlot(let item):
            return ASLLessonPromptFraming.prompt(
                for: .fillSlot,
                lessonId: lessonId,
                stepIndex: stepIndex,
                wordId: item.answerWordId
            )
        case .phraseSlot(let item):
            return ASLLessonPromptFraming.prompt(
                for: .phraseSlot,
                lessonId: lessonId,
                stepIndex: stepIndex,
                wordId: item.answerWordId
            )
        case .signSequence:
            return ASLLessonPromptFraming.prompt(
                for: .signSequence,
                lessonId: lessonId,
                stepIndex: stepIndex
            )
        default:
            return nil
        }
    }

    private static func isWordPickStep(_ step: ModulePlayStep) -> Bool {
        switch step {
        case .watchChoose, .translationChoose,
             .wordPickVideo, .fillSlot, .phraseSlot:
            return true
        default:
            return false
        }
    }

    private static func pickAnswerWordId(for step: ModulePlayStep) -> String? {
        switch step {
        case .watchChoose(let item), .translationChoose(let item):
            return item.answerWordId
        case .wordPickVideo(let item):
            return item.answerWordId
        case .fillSlot(let item):
            return item.answerWordId
        case .phraseSlot(let item):
            return item.answerWordId
        default:
            return nil
        }
    }

    private static func gradedAnswerTokens(for step: ModulePlayStep) -> Set<String> {
        var tokens = Set(step.gradedAnswerWordIds)
        if let phraseId = phraseVideoWordId(for: step) {
            tokens.insert(phraseId)
        }
        return tokens
    }

    private static func isIntroConfirmPair(_ prev: ModulePlayStep, _ curr: ModulePlayStep) -> Bool {
        guard case .teach(let item) = prev, !item.isPracticeReplay else { return false }
        guard let answer = pickAnswerWordId(for: curr) else { return false }
        switch curr {
        case .watchChoose, .translationChoose, .wordPickVideo:
            return item.wordId == answer
        default:
            return false
        }
    }

    private static func adjacentGradedAnswerConflict(
        _ prev: ModulePlayStep,
        _ curr: ModulePlayStep
    ) -> Bool {
        guard prev.isGradedQuestionStep, curr.isGradedQuestionStep else { return false }
        if isIntroConfirmPair(prev, curr) { return false }
        let previousTokens = gradedAnswerTokens(for: prev)
        let currentTokens = gradedAnswerTokens(for: curr)
        if previousTokens.isEmpty || currentTokens.isEmpty { return false }
        return !previousTokens.isDisjoint(with: currentTokens)
    }

    private static func stepKindTag(_ step: ModulePlayStep) -> String {
        switch step {
        case .teach: return "teach"
        case .wordPickVideo: return "wordPickVideo"
        case .watchChoose: return "watchChoose"
        case .translationChoose: return "translationChoose"
        case .signSequence: return "signSequence"
        case .phraseSlot: return "phraseSlot"
        case .fillSlot: return "fillSlot"
        case .matchPairs: return "matchPairs"
        case .yourTurn: return "yourTurn"
        case .aslTip: return "aslTip"
        }
    }

    /// True if `steps[index]` repeats the prior graded step's answer, or forms a
    /// run of three consecutive steps of the same exercise type.
    private static func variolatesAt(_ steps: [ModulePlayStep], _ index: Int) -> Bool {
        guard index >= 1, index < steps.count else { return false }
        if adjacentGradedAnswerConflict(steps[index - 1], steps[index]) {
            return true
        }
        if index >= 2,
           stepKindTag(steps[index]) == stepKindTag(steps[index - 1]),
           stepKindTag(steps[index]) == stepKindTag(steps[index - 2]) {
            return true
        }
        return false
    }

    private static func introIndex(for wordId: String, in steps: [ModulePlayStep]) -> Int? {
        for (index, step) in steps.enumerated() {
            if case .teach(let item) = step, item.wordId == wordId, !item.isPracticeReplay {
                return index
            }
        }
        return nil
    }

    private static func swapPreservesIntroOrder(
        _ steps: [ModulePlayStep],
        left: Int,
        right: Int
    ) -> Bool {
        var trial = steps
        trial.swapAt(left, right)
        for index in [left, right] {
            guard isWordPickStep(trial[index]),
                  let answer = pickAnswerWordId(for: trial[index]) else { continue }
            if let intro = introIndex(for: answer, in: trial), index <= intro {
                return false
            }
        }
        return true
    }

    /// Length-preserving re-spacing: instead of dropping back-to-back same-answer
    /// steps, swap nearby graded steps so the same correct answer never appears
    /// twice in a row and no exercise type appears three times consecutively.
    /// Passive steps (teach / ASL Tip / Your Turn / self-sign) are never moved so
    /// teach→confirm adjacency is preserved.
    private static func respaceForVariety(_ steps: [ModulePlayStep]) -> [ModulePlayStep] {
        guard steps.count > 2 else { return steps }
        var result = steps
        var index = 1
        while index < result.count {
            if !variolatesAt(result, index) || isPassiveStep(result[index]) {
                index += 1
                continue
            }
            var swapped = false
            var candidate = index + 1
            while candidate < result.count {
                if !isPassiveStep(result[candidate]) {
                    result.swapAt(index, candidate)
                    if swapPreservesIntroOrder(result, left: index, right: candidate),
                       !variolatesAt(result, index) && !variolatesAt(result, candidate) {
                        swapped = true
                        break
                    }
                    result.swapAt(index, candidate)
                }
                candidate += 1
            }
            index += 1
            _ = swapped
        }
        return result
    }

    /// Swap graded steps so no two consecutive exercises share a sign or phrase answer.
    private static func enforceNoAdjacentSameGradedAnswer(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result = steps
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":answer-spacing")
        )
        let pool = lesson.wordIds.filter { !ASLPhraseIds.contains($0) }

        for _ in 0..<(result.count * 3) {
            var changed = false
            for index in 1..<result.count {
                let prev = result[index - 1]
                let curr = result[index]
                guard adjacentGradedAnswerConflict(prev, curr) else { continue }

                let prevTokens = gradedAnswerTokens(for: prev)
                let currTokens = gradedAnswerTokens(for: curr)
                var swapIndex: Int?

                for later in (index + 1)..<result.count {
                    let laterTokens = gradedAnswerTokens(for: result[later])
                    if !laterTokens.isDisjoint(with: currTokens) { continue }
                    if later == index + 1, !laterTokens.isDisjoint(with: prevTokens) { continue }
                    if !swapPreservesIntroOrder(result, left: index, right: later) { continue }

                    var trial = result
                    trial.swapAt(index, later)
                    if adjacentGradedAnswerConflict(trial[index - 1], trial[index]) { continue }
                    if index + 1 < trial.count,
                       adjacentGradedAnswerConflict(trial[index], trial[index + 1]) {
                        continue
                    }
                    swapIndex = later
                    break
                }

                if let swapIndex {
                    result.swapAt(index, swapIndex)
                    changed = true
                    break
                }

                let forbidden = prevTokens.union(currTokens)
                guard let alt = pool.first(where: { !forbidden.contains($0) }) else { continue }

                switch curr {
                case .watchChoose, .translationChoose, .wordPickVideo, .fillSlot, .phraseSlot:
                    result[index] = variedConfirmPick(
                        for: alt,
                        lesson: lesson,
                        stepIndex: index,
                        generator: &generator
                    )
                    changed = true
                case .signSequence, .matchPairs:
                    result[index] = variedConfirmPick(
                        for: alt,
                        lesson: lesson,
                        stepIndex: index,
                        preferNonWatchChoose: true,
                        generator: &generator
                    )
                    changed = true
                default:
                    break
                }
                if changed { break }
            }
            if !changed { break }
        }

        return result
    }

    private static func phraseVideoWordId(for step: ModulePlayStep) -> String? {
        switch step {
        case .signSequence(let item):
            return item.phraseWordId
        case .phraseSlot(let item):
            return item.phraseWordId
        case .fillSlot(let item):
            return item.phraseWordId
        default:
            return nil
        }
    }

    private static func collapseAdjacentSamePhraseVideoSteps(in steps: [ModulePlayStep]) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }
        var result: [ModulePlayStep] = []
        for step in steps {
            if let previous = result.last,
               let prevId = phraseVideoWordId(for: previous),
               let currId = phraseVideoWordId(for: step),
               prevId == currId {
                continue
            }
            result.append(step)
        }
        return result
    }

    /// Never run two match-pair rounds back to back — swap in a single-sign pick instead.
    private static func separateAdjacentMatchPairsSteps(
        in steps: [ModulePlayStep],
        lesson: ASLLesson
    ) -> [ModulePlayStep] {
        guard steps.count >= 2 else { return steps }

        var result: [ModulePlayStep] = []
        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64(lesson.id + ":match-pairs-fix")
        )

        for step in steps {
            if case .matchPairs(let item) = step,
               let last = result.last,
               case .matchPairs = last {
                let prevTokens = gradedAnswerTokens(for: last)
                let wordId = item.wordIds.first { !prevTokens.contains($0) } ?? item.wordIds.first
                if let wordId {
                    result.append(
                        variedConfirmPick(
                            for: wordId,
                            lesson: lesson,
                            stepIndex: result.count,
                            preferNonWatchChoose: true,
                            generator: &generator
                        )
                    )
                    continue
                }
            }
            result.append(step)
        }

        return result
    }

    private static let carryoverPrompt = "Let's revisit this one."

    private static func applyMistakeCarryover(
        to steps: inout [ModulePlayStep],
        lesson: ASLLesson,
        store: ASLDataStore
    ) {
        guard lesson.type == .module,
              lesson.sortOrder >= 2,
              !lesson.id.hasSuffix("-review") else { return }
        guard let wordId = store.carryoverWord(for: lesson.unitId, stoneSortOrder: lesson.sortOrder),
              lesson.wordIds.contains(wordId) else { return }

        let searchStart = 4
        let searchEnd = min(12, steps.count)
        if searchStart < searchEnd {
            for index in searchStart..<searchEnd {
                switch steps[index] {
                case .watchChoose(let item):
                    guard item.answerWordId != wordId else { return }
                    var generator = SystemRandomNumberGenerator()
                    steps[index] = .watchChoose(
                        makePickItem(
                            answer: wordId,
                            lesson: lesson,
                            authoredDistractors: [],
                            choiceCount: item.choices.count,
                            prompt: carryoverPrompt,
                            preferSemanticDistractors: true,
                            generator: &generator
                        )
                    )
                    store.markCarryoverSurfaced(unitId: lesson.unitId, wordId: wordId)
                    return
                case .translationChoose(let item):
                    guard item.answerWordId != wordId else { return }
                    var generator = SystemRandomNumberGenerator()
                    steps[index] = .translationChoose(
                        makePickItem(
                            answer: wordId,
                            lesson: lesson,
                            authoredDistractors: [],
                            choiceCount: item.choices.count,
                            prompt: carryoverPrompt,
                            preferSemanticDistractors: true,
                            generator: &generator
                        )
                    )
                    store.markCarryoverSurfaced(unitId: lesson.unitId, wordId: wordId)
                    return
                default:
                    continue
                }
            }
        }

        let insertIndex = min(6, steps.count)
        var generator = SystemRandomNumberGenerator()
        steps.insert(
            .watchChoose(
                makePickItem(
                    answer: wordId,
                    lesson: lesson,
                    authoredDistractors: [],
                    choiceCount: 2,
                    prompt: carryoverPrompt,
                    preferSemanticDistractors: true,
                    generator: &generator
                )
            ),
            at: insertIndex
        )
        store.markCarryoverSurfaced(unitId: lesson.unitId, wordId: wordId)
    }

    private static func teachDisplayTitle(
        for wordId: String,
        lessonId: String,
        stepIndex: Int,
        isPracticeReplay: Bool = false
    ) -> String {
        ASLLessonPromptFraming.teachTitle(
            for: wordId,
            lessonId: lessonId,
            stepIndex: stepIndex,
            isPracticeReplay: isPracticeReplay
        )
    }

    private static func teachDisplayPrompt(for wordId: String) -> String {
        ASLPhraseIds.contains(wordId) ? "Learn the full motion." : "Continue when it feels familiar."
    }

    private static func makeTeachItem(
        wordId: String,
        lessonId: String,
        stepIndex: Int,
        authoredTitle: String = "",
        authoredPrompt: String = ""
    ) -> ModuleTeachItem {
        ModuleTeachItem(
            wordId: wordId,
            title: authoredTitle.isEmpty
                ? ASLLessonPromptFraming.teachTitle(
                    for: wordId,
                    lessonId: lessonId,
                    stepIndex: stepIndex
                )
                : authoredTitle,
            prompt: authoredPrompt.isEmpty
                ? teachDisplayPrompt(for: wordId)
                : authoredPrompt
        )
    }

    private static func choicePool(for answer: String, in lesson: ASLLesson) -> [String] {
        if ASLPhraseIds.contains(answer) {
            return Array(ASLPhraseIds.ids)
        }
        return lesson.wordIds
    }

    /// Recognition tiles are always two or four options — never an odd count.
    private static func normalizedChoiceCount(_ count: Int) -> Int {
        count > 2 ? 4 : 2
    }

    private static func makePickItem<G: RandomNumberGenerator>(answer: String,
                                     lesson: ASLLesson,
                                     authoredDistractors: [String],
                                     choiceCount: Int,
                                     prompt: String,
                                     preferSemanticDistractors: Bool = false,
                                     generator: inout G) -> ModulePickItem {
        let safeChoiceCount = normalizedChoiceCount(choiceCount)
        let neededDistractors = max(0, safeChoiceCount - 1)
        let pool = choicePool(for: answer, in: lesson)
        let phraseAnswer = ASLPhraseIds.contains(answer)

        // Start with authored distractors (with the answer stripped out if it
        // somehow appeared in the list).
        var distractors = authoredDistractors.filter { $0 != answer }
        if phraseAnswer {
            distractors = distractors.filter { ASLPhraseIds.contains($0) }
        }

        // Top up from the rest of the lesson's vocabulary if we don't have
        // enough distractors yet.
        if distractors.count < neededDistractors {
            if preferSemanticDistractors && !phraseAnswer {
                let semantic = ASLSemanticDistractors.candidates(for: answer, pool: pool)
                    .filter { !distractors.contains($0) }
                distractors.append(
                    contentsOf: semantic.prefix(neededDistractors - distractors.count)
                )
            }
            if distractors.count < neededDistractors {
                let extras = pool
                    .filter { $0 != answer && !distractors.contains($0) }
                    .shuffled(using: &generator)
                    .prefix(neededDistractors - distractors.count)
                distractors.append(contentsOf: extras)
            }
        }

        // Pick exactly `neededDistractors` from the pool, then append the
        // answer so it's guaranteed to be in the final choice set, *then*
        // shuffle position. Previously we shuffled answer + distractors
        // together and took a prefix, which could silently drop the answer
        // when the authored pool had more distractors than the question
        // wanted (the watchPick2 bug).
        distractors.shuffle(using: &generator)
        var choices = Array(distractors.prefix(neededDistractors))
        choices.append(answer)
        if phraseAnswer {
            choices = choices.filter { ASLPhraseIds.contains($0) }
        }
        if choices.count < safeChoiceCount {
            let topUp = pool
                .filter { candidate in
                    candidate != answer
                        && !choices.contains(candidate)
                        && (!phraseAnswer || ASLPhraseIds.contains(candidate))
                }
                .shuffled(using: &generator)
            for candidate in topUp where choices.count < safeChoiceCount {
                choices.append(candidate)
            }
        }
        while choices.count > safeChoiceCount,
              let dropIndex = choices.firstIndex(where: { $0 != answer }) {
            choices.remove(at: dropIndex)
        }
        if choices.count % 2 != 0,
           let dropIndex = choices.firstIndex(where: { $0 != answer }) {
            choices.remove(at: dropIndex)
        }
        choices.shuffle(using: &generator)

        return ModulePickItem(
            answerWordId: answer,
            choices: choices,
            prompt: prompt
        )
    }

    private static func makeSignSequenceItem<G: RandomNumberGenerator>(
        phraseId: String,
        sequence: [String],
        lesson: ASLLesson,
        authoredDistractors: [String],
        prompt: String,
        generator: inout G
    ) -> SignSequenceItem {
        // Use authored sequence tiles as-is. Compound phrase signs (dontknow, notyet)
        // are valid steps — do not strip every phrase id, which collapsed sequences
        // like i + dontknow down to a single "I" tile.
        let tiles = sequence.filter { $0 != phraseId || sequence.contains(where: { $0 != phraseId }) }
        var choices = tiles
        choices.append(
            contentsOf: authoredDistractors.filter {
                $0 != phraseId
                    && !tiles.contains($0)
                    && !ASLPhraseIds.contains($0)
            }
        )
        if tiles.count >= 3, choices.count <= tiles.count {
            let pool = lesson.wordIds.filter { wordId in
                wordId != phraseId
                    && !tiles.contains(wordId)
                    && !ASLPhraseIds.contains(wordId)
            }
            let extras = pool.shuffled(using: &generator).prefix(1)
            choices.append(contentsOf: extras)
        }
        choices = Array(Set(choices))
        choices.shuffle(using: &generator)
        return SignSequenceItem(
            phraseWordId: phraseId,
            sequenceWordIds: tiles,
            choices: choices,
            prompt: prompt
        )
    }

    private static func makePhraseSlotItem<G: RandomNumberGenerator>(
        phraseId: String,
        sequence: [String],
        slotIndex: Int,
        answer: String,
        lesson: ASLLesson,
        authoredDistractors: [String],
        prompt: String,
        generator: inout G
    ) -> PhraseSlotItem {
        let prefilledSlots = Set(
            sequence.enumerated()
                .filter { $0.offset != slotIndex }
                .map(\.element)
        )
        let neededDistractors = 1
        let pool = lesson.wordIds.filter { !ASLPhraseIds.contains($0) }

        var distractors = authoredDistractors.filter {
            $0 != answer
                && !prefilledSlots.contains($0)
                && !ASLPhraseIds.contains($0)
        }

        if distractors.count < neededDistractors {
            let semantic = ASLSemanticDistractors.candidates(for: answer, pool: pool)
                .filter { !prefilledSlots.contains($0) && !distractors.contains($0) }
            distractors.append(
                contentsOf: semantic.prefix(neededDistractors - distractors.count)
            )
        }
        if distractors.count < neededDistractors {
            let extras = pool
                .filter {
                    $0 != answer
                        && !prefilledSlots.contains($0)
                        && !distractors.contains($0)
                }
                .shuffled(using: &generator)
                .prefix(neededDistractors - distractors.count)
            distractors.append(contentsOf: extras)
        }

        distractors.shuffle(using: &generator)
        var choices = Array(distractors.prefix(neededDistractors))
        choices.append(answer)
        choices.shuffle(using: &generator)

        return PhraseSlotItem(
            phraseWordId: phraseId,
            sequenceWordIds: sequence,
            slotIndex: slotIndex,
            answerWordId: answer,
            choices: choices,
            prompt: prompt
        )
    }

    private func signSequenceChoicePool(for item: SignSequenceItem) -> [String] {
        item.choices
    }

    private static func makeWordPickVideoItem<G: RandomNumberGenerator>(answer: String,
                                              lesson: ASLLesson,
                                              authoredDistractors: [String],
                                              prompt: String,
                                              generator: inout G) -> WordPickVideoItem {
        let pick = makePickItem(
            answer: answer,
            lesson: lesson,
            authoredDistractors: authoredDistractors,
            choiceCount: 2,
            prompt: prompt,
            generator: &generator
        )
        return WordPickVideoItem(
            answerWordId: pick.answerWordId,
            choices: pick.choices,
            labels: ["Video A", "Video B"],
            prompt: pick.prompt
        )
    }


    private static func makeFillGapItem<G: RandomNumberGenerator>(answer: String,
                                        step: ModuleStep,
                                        lesson: ASLLesson,
                                        prompt: String = "",
                                        phraseWordId: String? = nil,
                                        generator: inout G) -> FillGapPlayItem {
        let minChoices = normalizedChoiceCount(step.choiceCount ?? 2)
        let neededDistractors = max(1, minChoices - 1)
        let phraseAnswer = ASLPhraseIds.contains(answer)
        var pool = choicePool(for: answer, in: lesson)
        if !phraseAnswer {
            pool = pool.filter { !ASLPhraseIds.contains($0) }
        }

        var distractors = step.distractorWordIds.filter { $0 != answer }
        if phraseAnswer {
            distractors = distractors.filter { ASLPhraseIds.contains($0) }
        } else {
            distractors = distractors.filter { !ASLPhraseIds.contains($0) }
        }

        func topUpDistractors(from candidates: [String]) {
            guard distractors.count < neededDistractors else { return }
            let extras = candidates
                .filter { $0 != answer && !distractors.contains($0) }
                .shuffled(using: &generator)
                .prefix(neededDistractors - distractors.count)
            distractors.append(contentsOf: extras)
        }

        topUpDistractors(from: ASLSemanticDistractors.candidates(for: answer, pool: pool))
        topUpDistractors(from: pool)
        if !phraseAnswer {
            topUpDistractors(from: ASLSemanticDistractors.singleWordPeers(for: answer))
        }

        distractors.shuffle(using: &generator)
        var choices = Array(distractors.prefix(neededDistractors))
        choices.append(answer)
        if phraseAnswer {
            choices = choices.filter { ASLPhraseIds.contains($0) }
        }
        choices.shuffle(using: &generator)

        let resolvedPhrase = phraseWordId.flatMap { $0 == answer ? nil : $0 }

        return FillGapPlayItem(
            before: step.sentenceBefore,
            after: step.sentenceAfter,
            answerWordId: answer,
            choices: choices,
            prompt: prompt,
            phraseWordId: resolvedPhrase
        )
    }

    private static func makeMatchPairWords(authored: [String], answer: String?, lesson: ASLLesson) -> [String] {
        var words: [String] = []
        for word in authored where lesson.wordIds.contains(word) && !words.contains(word) {
            words.append(word)
        }
        if let answer, lesson.wordIds.contains(answer), !words.contains(answer) {
            words.insert(answer, at: 0)
        }
        return Array(words.prefix(4))
    }
}
