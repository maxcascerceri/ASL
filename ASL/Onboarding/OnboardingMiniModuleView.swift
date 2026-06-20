//
//  OnboardingMiniModuleView.swift
//  ASL
//

import SwiftUI
import AVFoundation

private enum OnboardingMiniModuleMetrics {
    static let contentTopPadding: CGFloat = 40
    static let promptFontSize: CGFloat = LessonQuestionLayout.promptFontSize + 2
    /// Pinned progress header band — top inset + chrome row + bottom inset.
    static let progressHeaderBandHeight: CGFloat = 56
}

struct OnboardingMiniModuleView: View {
    @ObservedObject var store: ASLDataStore
    let onFinished: (_ score: Int, _ signsLearned: Int) -> Void

    @StateObject private var playerController = LessonPlayerController()
    @State private var stepIndex = 0
    @State private var correctCount = 0
    @State private var totalGraded = 0
    @State private var tileStates: [ChoiceTileState] = []
    @State private var lockTaps = false
    @State private var navigationButton: ModuleNavigationButtonState = .waiting("Choose an answer")
    @State private var selectedChoiceIndex: Int?
    @State private var selectedChoiceWordId: String?
    @State private var wrongFeedbackIndex = 0
    @State private var correctFeedbackIndex = 0
    @State private var continueActionTitleIndex = 0
    @State private var yourTurnPhase: YourTurnPhase = .watch
    @State private var showFirstSignCelebration = false

    // Match-pairs state (mirrors ModuleLessonView)
    @State private var matchBoardWordIds: [String] = []
    @State private var matchRemainingWordIds: [String] = []
    @State private var matchResolvedWordIds: Set<String> = []
    @State private var matchPlayColumnOrder: [String] = []
    @State private var matchTranslationColumnOrder: [String] = []
    @State private var selectedMatchVideoWordId: String?
    @State private var selectedMatchTranslationWordId: String?
    @State private var matchPairFlash: MatchPairFlash?
    @State private var matchPairFeedbackWorkItem: DispatchWorkItem?
    @State private var attachedVideoWordId: String?

    private let steps = OnboardingMiniModuleSteps.build()
    private let signsLearned = OnboardingMiniModuleSteps.signsLearnedCount
    private let palette = Brand.primary
    private let paletteShadow = Brand.primaryShadow

    private var lessonProgress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(stepIndex + 1) / Double(steps.count)
    }

    private var currentStep: OnboardingMiniStep {
        steps[min(stepIndex, steps.count - 1)]
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        stepContentContainer
                            .frame(
                                width: proxy.size.width,
                                height: max(0, proxy.size.height - OnboardingMiniModuleMetrics.progressHeaderBandHeight),
                                alignment: .top
                            )
                            .position(
                                x: proxy.size.width / 2,
                                y: OnboardingMiniModuleMetrics.progressHeaderBandHeight
                                    + max(0, proxy.size.height - OnboardingMiniModuleMetrics.progressHeaderBandHeight) / 2
                            )

                        progressHeader
                            .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .frame(
                                width: proxy.size.width,
                                height: OnboardingMiniModuleMetrics.progressHeaderBandHeight,
                                alignment: .top
                            )
                            .background(Brand.canvas)
                            .position(
                                x: proxy.size.width / 2,
                                y: OnboardingMiniModuleMetrics.progressHeaderBandHeight / 2
                            )
                            .zIndex(100)
                    }
                }

                actionTray
            }

            if showFirstSignCelebration {
                OnboardingFirstSignCelebrationView(
                    wordDisplayTitle: OnboardingMiniModuleSteps.displayTitle(
                        for: OnboardingMiniModuleSteps.yourTurnReferenceWordId
                    ),
                    onContinue: dismissFirstSignCelebration
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.canvas.ignoresSafeArea())
        .onAppear {
            prepareStep()
        }
        .onChange(of: stepIndex) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                prepareStep()
            }
        }
    }

    private var progressHeader: some View {
        OnboardingFlowProgressHeader(progress: lessonProgress, animatesFill: false)
            .animation(nil, value: stepIndex)
            .animation(nil, value: lessonProgress)
    }

    private var stepContentContainer: some View {
        stepContent
            .id(stepIndex)
            .transition(.identity)
            .padding(.top, OnboardingMiniModuleMetrics.contentTopPadding)
            .padding(.bottom, LessonActionTrayLayout.contentInsetAboveTray(for: navigationButton))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep.kind {
        case .teach:
            teachView
        case .watchChoose, .translationChoose:
            watchChooseView
        case .wordPickVideo:
            wordPickVideoView
        case .fillSlot:
            fillSlotView
        case .matchPairs:
            matchPairsView
        case .yourTurn:
            yourTurnView
        }
    }

    private var yourTurnView: some View {
        YourTurnStepView(
            lessonId: "onboarding-mini",
            referenceWordId: OnboardingMiniModuleSteps.yourTurnReferenceWordId,
            title: "Now you try!",
            prompt: "Sign Please yourself.",
            phase: $yourTurnPhase,
            store: store,
            palette: palette,
            paletteShadow: paletteShadow
        )
        .onChange(of: yourTurnPhase) { _, phase in
            syncYourTurnTray(for: phase)
        }
    }

    private var teachView: some View {
        LessonStepStack {
            LessonPromptLabel(
                text: "New sign!",
                fontSize: OnboardingMiniModuleMetrics.promptFontSize,
                eyebrow: currentStep.showsWatchAndLearnIntro ? "WATCH & LEARN" : nil,
                eyebrowColor: palette
            )
        } media: {
            lessonVideo(
                wordId: currentStep.videoWordId,
                height: LessonQuestionLayout.videoHeightCompact,
                lowered: true
            )
        } controls: {
            Text(currentStep.displayWord)
                .font(LessonQuestionLayout.teachWordFont)
                .foregroundStyle(palette)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }

    private var watchChooseView: some View {
        LessonStepStack {
            questionPrompt(for: currentStep)
        } media: {
            lessonVideo(
                wordId: currentStep.videoWordId,
                height: LessonQuestionLayout.videoHeightCompact,
                lowered: currentStep.choices.count <= 2
            )
        } controls: {
            selectableChoiceGrid(choices: currentStep.choices)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }

    private var wordPickVideoView: some View {
        LessonStepStack(spacing: 14) {
            questionPrompt(for: currentStep)
        } media: {
            SelectableStackedVideoChoiceView(
                wordIds: currentStep.choices,
                selectedWordId: selectedChoiceWordId,
                tileStates: tileStates,
                store: store,
                height: LessonQuestionLayout.wordPickVideoCardHeight,
                palette: palette,
                paletteShadow: paletteShadow
            ) { index, picked in
                selectChoice(index: index, picked: picked)
            }
            .padding(.horizontal, 6)
        } controls: {
            EmptyView()
        }
        .padding(.horizontal, 18)
    }

    private var fillSlotView: some View {
        LessonStepStack(spacing: 14) {
            LessonPromptLabel(
                text: fillSlotPrompt,
                fontSize: OnboardingMiniModuleMetrics.promptFontSize,
                useInstructionWeight: true
            )
        } media: {
            VStack(spacing: 14) {
                lessonVideo(
                    wordId: currentStep.videoWordId,
                    height: LessonQuestionLayout.videoHeightCompact
                )
                HStack(spacing: 6) {
                    Text(currentStep.sentenceBefore)
                        .font(LessonQuestionLayout.sentenceFont)
                    fillSlotChip
                    Text(currentStep.sentenceAfter)
                        .font(LessonQuestionLayout.sentenceFont)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.52)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .animation(nil, value: selectedChoiceWordId)
            }
        } controls: {
            selectableChoiceGrid(choices: currentStep.choices)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }

    private var fillSlotPrompt: String {
        ASLLessonPromptFraming.prompt(
            for: .fillSlot,
            lessonId: "onboarding-mini",
            stepIndex: stepIndex
        )
    }

    private var fillSlotChipForeground: Color {
        guard selectedChoiceWordId != nil else { return palette }
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
        guard selectedChoiceWordId != nil else { return palette.opacity(0.18) }
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
        guard selectedChoiceWordId != nil else { return palette.opacity(0.7) }
        switch navigationButton {
        case .correct:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        default:
            return palette
        }
    }

    private var fillSlotChipBorderWidth: CGFloat {
        selectedChoiceWordId == nil ? 2 : 3
    }

    private var fillSlotChip: some View {
        ZStack {
            if let wordId = selectedChoiceWordId {
                Text(OnboardingMiniModuleSteps.displayTitle(for: wordId))
                    .font(LessonQuestionLayout.chipFont)
                    .foregroundStyle(fillSlotChipForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 10)
            }
        }
        .frame(minWidth: 72, minHeight: 38)
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

    private var matchPairsView: some View {
        MatchPairsStepLayout(
            prompt: matchPairsPrompt,
            pairCount: currentStep.choices.count
        ) {
            matchPairsVideoStage
        } controls: {
            MatchPairControlsRow(
                wordColumnWidth: MatchPairLayout.wordTileWidth(
                    for: matchTranslationColumnOrder.map { OnboardingMiniModuleSteps.displayTitle(for: $0) }
                )
            ) {
                ForEach(matchPlayColumnOrder, id: \.self) { wordId in
                    let flash = matchPairPlayFlashStates(for: wordId)
                    MatchPairPlayTile(
                        palette: palette,
                        paletteShadow: paletteShadow,
                        isSelected: selectedMatchVideoWordId == wordId,
                        isResolved: matchResolvedWordIds.contains(wordId),
                        flashWrong: flash.wrong,
                        flashCorrect: flash.correct,
                        accessibilitySignLabel: OnboardingMiniModuleSteps.displayTitle(for: wordId)
                    ) {
                        selectMatchVideo(wordId)
                    }
                }
            } wordColumn: {
                ForEach(matchTranslationColumnOrder, id: \.self) { wordId in
                    let flash = matchPairWordFlashStates(for: wordId)
                    MatchPairWordTile(
                        title: OnboardingMiniModuleSteps.displayTitle(for: wordId),
                        palette: palette,
                        paletteShadow: paletteShadow,
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
        .onChange(of: selectedMatchVideoWordId) { _, newValue in
            guard currentStep.kind == .matchPairs else { return }
            guard newValue == nil, !matchRemainingWordIds.isEmpty else { return }
            selectFirstAvailableMatchVideo()
        }
    }

    private var matchPairsVideoStage: some View {
        Group {
            if let wordId = selectedMatchVideoWordId, showsFilmPlaceholder(for: wordId) {
                SignFilmPlaceholder(
                    title: ASLPendingFilmCatalog.title(for: wordId, store: store),
                    height: MatchPairLayout.videoHeight,
                    cornerRadius: SignVideoCardMetrics.cornerRadius,
                    style: .stage
                )
                .elevation(.insetField)
            } else {
                LessonVideoPlayer(
                    controller: playerController,
                    cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                    videoGravity: .resizeAspectFill,
                    placeholderColor: Brand.homeBackground
                )
                .padding(SignVideoCardMetrics.innerPadding)
                .frame(maxWidth: .infinity)
                .frame(height: MatchPairLayout.videoHeight)
                .background(Brand.homeBackground)
                .clipShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
                }
                .overlay(alignment: .topTrailing) {
                    SignVideoControlsOverlay(controller: playerController)
                }
                .elevation(.insetField)
            }
        }
    }

    private var matchPairsPrompt: String {
        ASLLessonPromptFraming.prompt(
            for: .matchPairs,
            lessonId: "onboarding-mini",
            stepIndex: stepIndex
        )
    }

    private var actionTray: some View {
        LessonActionTray(
            state: navigationButton,
            palette: palette,
            paletteShadow: paletteShadow,
            action: tappedNavigationButton
        )
    }

    private func questionPrompt(for step: OnboardingMiniStep) -> LessonPromptLabel {
        let wordLabel = step.displayWord
        let text: String
        switch step.kind {
        case .watchChoose:
            text = "What sign is this?"
        case .translationChoose:
            text = ASLLessonPromptFraming.prompt(
                for: .translationChoose,
                lessonId: "onboarding-mini",
                stepIndex: stepIndex
            )
        case .wordPickVideo:
            text = "Which video shows \(wordLabel)?"
        default:
            text = wordLabel
        }

        return LessonPromptLabel(
            text: text,
            fontSize: OnboardingMiniModuleMetrics.promptFontSize,
            emphasizedSegment: LessonPromptLabel.emphasisSegment(forPrompt: text, wordLabel: wordLabel),
            emphasisColor: palette
        )
    }

    private func lessonVideo(
        wordId: String?,
        height: CGFloat = LessonQuestionLayout.videoHeight,
        lowered: Bool = false
    ) -> some View {
        Group {
            if let wordId, showsFilmPlaceholder(for: wordId) {
                SignFilmPlaceholder(
                    title: ASLPendingFilmCatalog.title(for: wordId, store: store),
                    height: height,
                    cornerRadius: SignVideoCardMetrics.cornerRadius,
                    style: .stage
                )
                .elevation(.insetField)
            } else {
                LessonVideoPlayer(
                    controller: playerController,
                    cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                    videoGravity: .resizeAspectFill,
                    placeholderColor: Brand.homeBackground
                )
                .padding(SignVideoCardMetrics.innerPadding)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Brand.homeBackground)
                .clipShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
                }
                .overlay(alignment: .topTrailing) {
                    SignVideoControlsOverlay(controller: playerController)
                }
                .elevation(.insetField)
            }
        }
        .padding(.top, lowered ? 4 : 0)
        .onAppear {
            if let wordId { ensureVideo(for: wordId) }
        }
        .onChange(of: wordId) { _, newValue in
            if let newValue { ensureVideo(for: newValue) }
        }
    }

    private func showsFilmPlaceholder(for wordId: String) -> Bool {
        ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store)
            || ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store)
    }

    private func selectableChoiceGrid(choices: [String]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: LessonQuestionLayout.choiceSpacing) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let isSelected = selectedChoiceIndex == index
                ChoiceTile(
                    label: OnboardingMiniModuleSteps.displayTitle(for: choice),
                    state: choiceTileState(at: index, isSelected: isSelected),
                    palette: palette,
                    paletteShadow: paletteShadow
                ) {
                    selectChoice(index: index, picked: choice)
                }
                .allowsHitTesting(!lockTaps)
            }
        }
    }

    private func choiceTileState(at index: Int, isSelected: Bool) -> ChoiceTileState {
        if tileStates.indices.contains(index), tileStates[index] != .rest {
            return tileStates[index]
        }
        return isSelected ? .selected : .rest
    }

    private func prepareStep() {
        lockTaps = false
        selectedChoiceIndex = nil
        selectedChoiceWordId = nil
        tileStates = []
        matchPairFeedbackWorkItem?.cancel()
        matchPairFlash = nil
        playerController.setSlowMotion(false)

        switch currentStep.kind {
        case .teach:
            navigationButton = .ready("Continue")
            if let wordId = currentStep.videoWordId { ensureVideo(for: wordId) }
        case .watchChoose, .translationChoose, .wordPickVideo, .fillSlot:
            tileStates = Array(repeating: .rest, count: currentStep.choices.count)
            navigationButton = .waiting("Choose an answer")
            if let wordId = currentStep.videoWordId ?? currentStep.answerWordId {
                ensureVideo(for: wordId)
            }
        case .matchPairs:
            navigationButton = .waiting("Choose an answer")
            resetMatchBoard(with: currentStep.choices)
        case .yourTurn:
            playerController.detach()
            yourTurnPhase = .watch
            syncYourTurnTray(for: .watch)
        }
    }

    private func syncYourTurnTray(for phase: YourTurnPhase) {
        switch phase {
        case .watch:
            navigationButton = .ready("Record now")
        case .review:
            navigationButton = .ready(OnboardingCopy.continueCTA)
        case .recording:
            break
        }
    }

    private func resetMatchBoard(with ids: [String]) {
        matchBoardWordIds = ids
        matchRemainingWordIds = ids
        matchResolvedWordIds = []
        selectedMatchTranslationWordId = nil
        matchPairFlash = nil
        rebuildMatchColumnOrders()
        selectFirstAvailableMatchVideo()
    }

    private func rebuildMatchColumnOrders() {
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

    private func selectMatchVideo(_ wordId: String) {
        guard matchRemainingWordIds.contains(wordId), !lockTaps else { return }
        selectedMatchVideoWordId = wordId
        Haptics.tap()
        ensureVideo(for: wordId)
        tryResolveMatchPair()
    }

    private func selectMatchTranslation(_ wordId: String) {
        guard matchRemainingWordIds.contains(wordId), !lockTaps else { return }
        selectedMatchTranslationWordId = wordId
        Haptics.tap()
        tryResolveMatchPair()
    }

    private func tryResolveMatchPair() {
        guard matchPairFlash == nil else { return }
        guard let videoWord = selectedMatchVideoWordId,
              let translationWord = selectedMatchTranslationWordId else { return }

        matchPairFeedbackWorkItem?.cancel()

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
                onRoundComplete: handleMatchRoundComplete,
                storeWorkItem: { matchPairFeedbackWorkItem = $0 }
            )
        } else {
            Haptics.wrong()
            matchPairFlash = .wrong(videoWordId: videoWord, translationWordId: translationWord)
            lockTaps = true

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

    private func selectChoice(index: Int, picked: String) {
        guard !lockTaps else { return }
        if tileStates.indices.contains(index), tileStates[index] == .wrong {
            tileStates[index] = .rest
        }
        selectedChoiceIndex = index
        selectedChoiceWordId = picked
        navigationButton = .checkAnswer
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        if currentStep.kind == .yourTurn {
            switch yourTurnPhase {
            case .watch:
                yourTurnPhase = .recording
                return
            case .recording:
                return
            case .review:
                showFirstSignCelebration = true
                return
            }
        }

        if case .checkAnswer = navigationButton {
            checkSelectedChoice()
            return
        }

        if case .ready = navigationButton {
            if currentStep.kind != .teach {
                Haptics.correct()
            }
        }

        advanceStep()
    }

    private func checkSelectedChoice() {
        guard let selectedChoiceWordId,
              let answerWordId = currentStep.answerWordId else { return }

        let choices = currentStep.choices
        let index = selectedChoiceIndex ?? choices.firstIndex(of: selectedChoiceWordId) ?? 0

        if selectedChoiceWordId == answerWordId {
            lockTaps = true
            totalGraded += 1
            correctCount += 1
            tileStates[index] = .correct
            Haptics.correct()
            navigationButton = .correct(
                headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
                actionTitle: nextContinueActionTitle()
            )
            correctFeedbackIndex += 1
        } else {
            lockTaps = true
            totalGraded += 1
            Haptics.wrong()
            revealWrong(index: index, answerWordId: answerWordId, choices: choices)
            navigationButton = .wrong(
                headline: ASLRedrillCopy.firstPassWrongHeadline(index: wrongFeedbackIndex),
                answer: OnboardingMiniModuleSteps.displayTitle(for: answerWordId),
                actionTitle: nextContinueActionTitle()
            )
            wrongFeedbackIndex += 1
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

    private func handleMatchRoundComplete() {
        lockTaps = true
        totalGraded += 1
        correctCount += 1
        navigationButton = .correct(
            headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
            actionTitle: nextContinueActionTitle()
        )
        correctFeedbackIndex += 1
    }

    private func dismissFirstSignCelebration() {
        guard showFirstSignCelebration else { return }
        showFirstSignCelebration = false
        advanceStep()
    }

    private func advanceStep() {
        if stepIndex + 1 >= steps.count {
            let score = totalGraded > 0 ? Int(Double(correctCount) / Double(totalGraded) * 100) : 100
            onFinished(score, signsLearned)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                stepIndex += 1
            }
        }
    }

    private func ensureVideo(for wordId: String) {
        attachedVideoWordId = wordId

        guard !showsFilmPlaceholder(for: wordId) else {
            playerController.detach()
            return
        }

        if store.hasPlayableVideo(for: wordId) {
            if playerController.loadedWordId == wordId, playerController.isPlaybackReady {
                playerController.resumeLooping()
                return
            }
            Task {
                await store.ensureVideoAttached(to: playerController, wordId: wordId)
                guard attachedVideoWordId == wordId else { return }
                playerController.playAtNormalSpeed()
                playerController.replay()
            }
            return
        }

        if let url = BundledSignMedia.playbackURL(for: wordId) {
            playerController.load(url, wordId: wordId)
            playerController.playAtNormalSpeed()
            playerController.replay()
        } else {
            playerController.detach()
        }
    }

    private func nextContinueActionTitle() -> String {
        if stepIndex >= steps.count - 1 {
            return OnboardingCopy.continueCTA
        }
        let titles = ["Continue", "Next question"]
        let title = titles[continueActionTitleIndex % titles.count]
        continueActionTitleIndex += 1
        return title
    }
}

// MARK: - Step model

enum OnboardingMiniStepKind {
    case teach
    case watchChoose
    case translationChoose
    case wordPickVideo
    case fillSlot
    case matchPairs
    case yourTurn
}

struct OnboardingMiniStep: Identifiable {
    let id = UUID()
    let kind: OnboardingMiniStepKind
    let displayWord: String
    let videoWordId: String?
    let answerWordId: String?
    let choices: [String]
    var sentenceBefore: String = ""
    var sentenceAfter: String = ""
    /// First exposure via watchChoose — "What sign is this?" instead of naming the answer.
    var isColdIntro: Bool = false
    /// Full WATCH & LEARN chrome — only the first formal teach beat.
    var showsWatchAndLearnIntro: Bool = false
}

enum OnboardingMiniModuleSteps {
    static let signsLearnedCount = vocabulary.count

    static let matchPairsSignCount = 4

    /// Hello and Please get a teach beat; other signs intro on their one graded exercise.
    private static let vocabulary: [OnboardingLessonSign] = [
        OnboardingLessonSign(wordId: "hello", displayTitle: "Hello"),
        OnboardingLessonSign(wordId: "thankyou", displayTitle: "Thank You"),
        OnboardingLessonSign(wordId: "please", displayTitle: "Please"),
        OnboardingLessonSign(wordId: "bye", displayTitle: "Goodbye"),
        OnboardingLessonSign(wordId: "good", displayTitle: "Good"),
    ]

    static func build() -> [OnboardingMiniStep] {
        let hello = sign(for: "hello")
        let thankyou = sign(for: "thankyou")
        let please = sign(for: "please")
        let bye = sign(for: "bye")

        // Two formal teaches; every sign is the correct answer exactly once.
        // Avoid teach → same-sign video quiz pairs except Hello (establishes the pattern).
        // Never place the same graded exercise kind back-to-back.
        return [
            teachStep(for: hello, showsWatchAndLearnIntro: true),
            gradedStep(for: hello, kind: .watchChoose),
            gradedStep(for: thankyou, kind: .translationChoose),
            teachStep(for: please),
            gradedStep(for: please, kind: .wordPickVideo),
            yourTurnStep(),
            gradedStep(for: bye, kind: .wordPickVideo),
            fillInPhraseStep(),
            OnboardingMiniStep(
                kind: .matchPairs,
                displayWord: "Match",
                videoWordId: nil,
                answerWordId: nil,
                choices: matchPairsWordIds
            ),
        ]
    }

    private static func sign(for wordId: String) -> OnboardingLessonSign {
        vocabulary.first { $0.wordId == wordId }
            ?? OnboardingLessonSign(wordId: wordId, displayTitle: ASLWordDisplay.title(for: wordId))
    }

    /// Reference sign for the Your Turn practice beat.
    static let yourTurnReferenceWordId = "please"

    private static func yourTurnStep() -> OnboardingMiniStep {
        OnboardingMiniStep(
            kind: .yourTurn,
            displayWord: displayTitle(for: yourTurnReferenceWordId),
            videoWordId: yourTurnReferenceWordId,
            answerWordId: nil,
            choices: []
        )
    }

    static func displayTitle(for wordId: String) -> String {
        if let sign = vocabulary.first(where: { $0.wordId == wordId }) {
            return sign.displayTitle
        }
        return ASLWordDisplay.title(for: wordId)
    }

    static var matchPairsWordIds: [String] {
        Array(vocabulary.prefix(matchPairsSignCount).map(\.wordId))
    }

    static var warmupWordIds: [String] {
        vocabulary.map(\.wordId) + ["goodmorning"]
    }

    private static func fillInPhraseStep() -> OnboardingMiniStep {
        let answerWordId = "good"
        let distractors = ["hello", "thankyou", "please"]
        return OnboardingMiniStep(
            kind: .fillSlot,
            displayWord: displayTitle(for: answerWordId),
            videoWordId: "goodmorning",
            answerWordId: answerWordId,
            choices: ([answerWordId] + distractors).shuffled(),
            sentenceBefore: "",
            sentenceAfter: " morning"
        )
    }

    private static func teachStep(
        for sign: OnboardingLessonSign,
        showsWatchAndLearnIntro: Bool = false
    ) -> OnboardingMiniStep {
        OnboardingMiniStep(
            kind: .teach,
            displayWord: sign.displayTitle,
            videoWordId: sign.wordId,
            answerWordId: nil,
            choices: [],
            showsWatchAndLearnIntro: showsWatchAndLearnIntro
        )
    }

    private static func gradedStep(
        for sign: OnboardingLessonSign,
        kind: OnboardingMiniStepKind,
        isColdIntro: Bool = false,
        distractorWordId: String? = nil
    ) -> OnboardingMiniStep {
        OnboardingMiniStep(
            kind: kind,
            displayWord: sign.displayTitle,
            videoWordId: showsVideoInPrompt(for: kind) ? sign.wordId : nil,
            answerWordId: sign.wordId,
            choices: choices(for: sign, kind: kind, distractorWordId: distractorWordId),
            isColdIntro: isColdIntro
        )
    }

    private static func showsVideoInPrompt(for kind: OnboardingMiniStepKind) -> Bool {
        switch kind {
        case .watchChoose, .translationChoose:
            return true
        default:
            return false
        }
    }

    private static func choices(
        for sign: OnboardingLessonSign,
        kind: OnboardingMiniStepKind,
        distractorWordId: String? = nil
    ) -> [String] {
        let otherSignIds = vocabulary
            .map(\.wordId)
            .filter { $0 != sign.wordId }

        switch kind {
        case .watchChoose:
            return ([sign.wordId] + Array(otherSignIds.prefix(3))).shuffled()
        case .translationChoose, .wordPickVideo:
            let distractor: String
            if let distractorWordId, otherSignIds.contains(distractorWordId) {
                distractor = distractorWordId
            } else if let index = vocabulary.firstIndex(where: { $0.wordId == sign.wordId }) {
                distractor = otherSignIds[index % otherSignIds.count]
            } else {
                distractor = otherSignIds[0]
            }
            return [sign.wordId, distractor].shuffled()
        default:
            return []
        }
    }
}

private struct OnboardingLessonSign {
    let wordId: String
    let displayTitle: String
}
