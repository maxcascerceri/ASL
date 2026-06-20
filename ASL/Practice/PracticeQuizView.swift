//
//  PracticeQuizView.swift
//  ASL
//

import SwiftUI

struct PracticeQuizView: View {
    @ObservedObject var store: ASLDataStore
    let wordIds: [String]
    var sourceUnitId: String? = nil

    @StateObject private var session: StoneSession<PracticeMixedQuizQuestion>
    @StateObject private var playerController = LessonPlayerController()
    @State private var tileStates: [ChoiceTileState] = []
    @State private var selectedChoiceIndex: Int?
    @State private var selectedChoiceWordId: String?
    @State private var selectedVideoWordId: String?
    @State private var navigationButton: ModuleNavigationButtonState = .waiting("Choose an answer")
    @State private var lockTaps = false
    @State private var showComplete = false
    @State private var attachedWordId: String?
    @State private var correctFeedbackIndex = 0
    @State private var wrongFeedbackIndex = 0
    @State private var continueActionTitleIndex = 0

    @Environment(\.dismiss) private var dismiss

    private enum Layout {
        static let videoHorizontalInset: CGFloat = 28
        static let contentTopInset: CGFloat = 16
    }

    init(store: ASLDataStore, wordIds: [String], sourceUnitId: String? = nil) {
        self.store = store
        self.wordIds = wordIds
        self.sourceUnitId = sourceUnitId
        _session = StateObject(wrappedValue: StoneSession(
            questions: Self.buildQuestions(from: wordIds, sourceUnitId: sourceUnitId)
        ))
    }

    var body: some View {
        ZStack {
            LessonShell(
                progress: session.progress,
                palette: PracticeTheme.accent,
                paletteShadow: PracticeTheme.accentShadow,
                leaveConfirmMessage: PracticeTheme.leaveConfirmMessage
            ) {
                ZStack(alignment: .bottom) {
                    questionContent
                        .padding(.top, Layout.contentTopInset)
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
                    mode: .quiz,
                    stats: .graded(
                        correct: session.correctCount,
                        total: session.questions.count,
                        bestStreak: session.bestStreak
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
        .onChange(of: session.currentIndex) { _, _ in startQuestion() }
        .onChange(of: store.mediaCacheRevision) { _, _ in reloadCurrentVideoIfNeeded() }
        .onChange(of: store.videoPlaybackRevision) { _, _ in reloadCurrentVideoIfNeeded() }
        .onAppear { startQuestion() }
        .task(id: wordIds) {
            store.loadWords(wordIds: wordIds)
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        if let question = session.current {
            VStack(spacing: LessonQuestionLayout.sectionSpacing) {
                questionBody(for: question)
                    .padding(.horizontal, question.kind == .wordPickVideo ? 18 : Layout.videoHorizontalInset)

                if question.kind != .wordPickVideo {
                    choiceGrid(question: question)
                        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
                }

                Spacer(minLength: 0)
            }
            .id(question.id)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        } else {
            ProgressView()
                .padding(.top, 80)
        }
    }

    @ViewBuilder
    private func questionBody(for question: PracticeMixedQuizQuestion) -> some View {
        switch question.kind {
        case .watchChoose:
            LessonWatchPickSection(
                controller: playerController,
                prompt: question.prompt,
                emphasizedSegment: emphasizedWord(in: question),
                emphasisColor: PracticeTheme.accent
            )
        case .translationChoose:
            LessonWatchPickSection(
                controller: playerController,
                prompt: question.prompt,
                emphasizedSegment: emphasizedWord(in: question),
                emphasisColor: PracticeTheme.accent,
                videoHeight: LessonQuestionLayout.videoHeightCompact
            )
        case .wordPickVideo:
            VStack(spacing: 14) {
                quizPromptLabel(for: question)
                SelectableStackedVideoChoiceView(
                    wordIds: question.choices,
                    selectedWordId: selectedVideoWordId,
                    tileStates: tileStates,
                    store: store,
                    height: LessonQuestionLayout.wordPickVideoCardHeight,
                    palette: PracticeTheme.accent,
                    paletteShadow: PracticeTheme.accentShadow
                ) { index, picked in
                    selectVideoPick(index: index, picked: picked)
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private func quizPromptLabel(for question: PracticeMixedQuizQuestion) -> LessonPromptLabel {
        let wordLabel = wordText(for: question.answerWordId)
        let isPhraseAnswer = ASLPhraseIds.contains(question.answerWordId)

        if question.kind == .wordPickVideo && isPhraseAnswer {
            return LessonPromptLabel(
                text: question.prompt,
                subtitle: wordLabel,
                subtitleWeight: LessonQuestionLayout.promptEmphasisWeight,
                subtitleForeground: PracticeTheme.accent
            )
        }

        return LessonPromptLabel(
            text: question.prompt,
            emphasizedSegment: emphasizedWord(in: question),
            emphasisColor: PracticeTheme.accent
        )
    }

    private func emphasizedWord(in question: PracticeMixedQuizQuestion) -> String? {
        let wordLabel = wordText(for: question.answerWordId)
        return LessonPromptLabel.emphasisSegment(forPrompt: question.prompt, wordLabel: wordLabel)
    }

    private func choiceGrid(question: PracticeMixedQuizQuestion) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: LessonQuestionLayout.choiceSpacing) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, wordId in
                ChoiceTile(
                    label: wordText(for: wordId),
                    state: tileState(for: idx, question: question),
                    palette: PracticeTheme.accent,
                    paletteShadow: PracticeTheme.accentShadow
                ) {
                    selectChoice(index: idx, picked: wordId, question: question)
                }
            }
        }
    }

    // MARK: - Session lifecycle

    private func startQuestion() {
        lockTaps = false
        selectedChoiceIndex = nil
        selectedChoiceWordId = nil
        selectedVideoWordId = nil
        guard let question = session.current else {
            finishSession()
            return
        }
        tileStates = Array(repeating: .rest, count: question.choices.count)
        navigationButton = .waiting("Choose an answer")
        switch question.kind {
        case .watchChoose, .translationChoose:
            ensureVideo(for: question.answerWordId)
        case .wordPickVideo:
            playerController.detach()
            attachedWordId = nil
        }
        prefetchUpcoming()
    }

    private func tileState(for index: Int, question: PracticeMixedQuizQuestion) -> ChoiceTileState {
        if tileStates.indices.contains(index), tileStates[index] != .rest {
            return tileStates[index]
        }
        if selectedChoiceIndex == index {
            return .selected
        }
        return .rest
    }

    private func selectChoice(index: Int, picked: String, question: PracticeMixedQuizQuestion) {
        guard !lockTaps else { return }
        if tileStates.indices.contains(index), tileStates[index] == .wrong {
            tileStates[index] = .rest
        }
        selectedChoiceIndex = index
        selectedChoiceWordId = picked
        navigationButton = .checkAnswer
    }

    private func selectVideoPick(index: Int, picked: String) {
        guard !lockTaps else { return }
        selectedChoiceIndex = index
        selectedChoiceWordId = picked
        selectedVideoWordId = picked
        navigationButton = .checkAnswer
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        if case .checkAnswer = navigationButton {
            checkSelectedChoice()
            return
        }

        if case .ready = navigationButton {
            Haptics.correct()
            LessonSounds.play(.correct)
        }

        advance()
    }

    private func checkSelectedChoice() {
        guard let question = session.current else { return }
        guard let picked = selectedChoiceWordId else { return }

        if picked == question.answerWordId {
            lockTaps = true
            session.recordCorrect()
            store.practiceDailyEngine.recordQuizCorrect(wordId: question.answerWordId)
            if question.kind == .wordPickVideo, let index = selectedChoiceIndex {
                markVideoCorrect(index: index, choiceCount: question.choices.count)
            } else if let index = selectedChoiceIndex {
                tileStates[index] = .correct
            }
            Haptics.correct()
            LessonSounds.play(.correct)
            navigationButton = .correct(
                headline: ASLCorrectFeedbackCopy.headline(index: correctFeedbackIndex),
                actionTitle: nextContinueActionTitle()
            )
            correctFeedbackIndex += 1
        } else {
            lockTaps = true
            session.recordWrong(wordId: question.answerWordId)
            Haptics.wrong()
            LessonSounds.play(.wrong)
            if question.kind == .wordPickVideo, let index = selectedChoiceIndex {
                markVideoWrong(index: index, question: question)
            } else if let index = selectedChoiceIndex {
                markWrong(index: index, question: question)
            }
            if question.kind != .wordPickVideo {
                playerController.playAtNormalSpeed()
                playerController.replay()
            }
            navigationButton = .wrong(
                headline: ASLRedrillCopy.firstPassWrongHeadline(index: wrongFeedbackIndex),
                answer: wordText(for: question.answerWordId),
                actionTitle: nextContinueActionTitle()
            )
            wrongFeedbackIndex += 1
        }
    }

    private func advance() {
        session.advance()
        if session.isComplete {
            finishSession()
        }
    }

    private func nextContinueActionTitle() -> String {
        PracticeContinueCopy.nextAction(index: &continueActionTitleIndex)
    }

    private func markWrong(index: Int, question: PracticeMixedQuizQuestion) {
        for i in tileStates.indices {
            if i == index {
                tileStates[i] = .wrong
            } else if question.choices[i] == question.answerWordId {
                tileStates[i] = .correctGlow
            } else {
                tileStates[i] = .dimmed
            }
        }
    }

    private func markVideoCorrect(index: Int, choiceCount: Int) {
        tileStates = (0..<choiceCount).map { idx in
            idx == index ? .correct : .dimmed
        }
    }

    private func markVideoWrong(index: Int, question: PracticeMixedQuizQuestion) {
        tileStates = question.choices.enumerated().map { idx, wordId in
            if idx == index { return .wrong }
            if wordId == question.answerWordId { return .correctGlow }
            return .dimmed
        }
    }

    private func prefetchUpcoming() {
        let questions = session.questions
        guard !questions.isEmpty else { return }
        var ids: [String] = []
        for offset in 1...3 {
            let index = session.currentIndex + offset
            guard index < questions.count else { break }
            let upcoming = questions[index]
            switch upcoming.kind {
            case .watchChoose, .translationChoose:
                ids.append(upcoming.answerWordId)
            case .wordPickVideo:
                ids.append(contentsOf: upcoming.choices)
            }
        }
        store.prioritizeQuizLookahead(wordIds: ids)
    }

    private func finishSession() {
        guard !showComplete else { return }
        store.recordQuizSessionComplete(unitId: sourceUnitId)
        store.recordDailyActivity()
        store.setPracticeSessionCompleteVisible(true)
        withAnimation(.easeIn(duration: 0.25)) {
            showComplete = true
        }
    }

    // MARK: - Helpers

    private static func buildQuestions(
        from wordIds: [String],
        sourceUnitId: String?
    ) -> [PracticeMixedQuizQuestion] {
        guard !wordIds.isEmpty else { return [] }

        let isWeakSignsDrill = wordIds.count <= 3 && sourceUnitId != nil
        let rotationSeed: Int
        if isWeakSignsDrill {
            rotationSeed = PracticeMixedQuizBuilder.rotationSeed(forWordIds: wordIds)
        } else {
            rotationSeed = PracticeMixedQuizBuilder.rotationSeed(
                forDayKey: ProfileDayKey.today(),
                fingerprint: wordIds.joined(separator: "|")
            )
        }
        let limit = isWeakSignsDrill ? wordIds.count : min(30, wordIds.count)
        return PracticeMixedQuizBuilder.buildSession(
            wordIds: wordIds,
            limit: limit,
            rotationSeed: rotationSeed
        )
    }

    private func wordText(for wordId: String) -> String {
        ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId)
    }

    private func reloadCurrentVideoIfNeeded() {
        guard let question = session.current else { return }
        guard question.kind != .wordPickVideo else { return }
        ensureVideo(for: question.answerWordId)
    }

    private func ensureVideo(for wordId: String) {
        attachedWordId = wordId
        Task {
            await store.ensureVideoAttached(to: playerController, wordId: wordId)
            guard attachedWordId == wordId else { return }
            playerController.playAtNormalSpeed()
            playerController.replay()
        }
    }
}

// MARK: - Practice choice builder

struct PracticePickChoices: Hashable {
    let answerWordId: String
    let choices: [String]
}

enum PracticeChoiceBuilder {
    static func normalizedChoiceCount(_ count: Int) -> Int {
        count > 2 ? 4 : 2
    }

    static func choicePool(for answer: String, in sessionPool: [String]) -> [String] {
        if ASLPhraseIds.contains(answer) {
            return Array(ASLPhraseIds.ids)
        }
        return sessionPool
    }

    static func buildChoices<G: RandomNumberGenerator>(
        answer: String,
        sessionPool: [String],
        choiceCount: Int,
        preferSemanticDistractors: Bool = true,
        generator: inout G
    ) -> PracticePickChoices {
        let safeChoiceCount = normalizedChoiceCount(choiceCount)
        let neededDistractors = max(0, safeChoiceCount - 1)
        let pool = choicePool(for: answer, in: sessionPool)
        let phraseAnswer = ASLPhraseIds.contains(answer)

        var distractors: [String] = []
        if preferSemanticDistractors && !phraseAnswer {
            let semantic = ASLSemanticDistractors.candidates(for: answer, pool: pool)
            distractors.append(contentsOf: semantic.prefix(neededDistractors))
        }
        if distractors.count < neededDistractors {
            let extras = pool
                .filter { $0 != answer && !distractors.contains($0) }
                .shuffled(using: &generator)
                .prefix(neededDistractors - distractors.count)
            distractors.append(contentsOf: extras)
        }

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

        return PracticePickChoices(answerWordId: answer, choices: choices)
    }
}

// MARK: - Mixed quiz builder

enum PracticeQuizQuestionKind: String, Hashable {
    case watchChoose
    case translationChoose
    case wordPickVideo
}

struct PracticeMixedQuizQuestion: Identifiable, Hashable {
    let id: String
    let kind: PracticeQuizQuestionKind
    let answerWordId: String
    let choices: [String]
    let prompt: String
}

enum PracticeMixedQuizBuilder {
    private static let kindRotation: [PracticeQuizQuestionKind] = [
        .watchChoose,
        .translationChoose,
        .wordPickVideo,
    ]

    static func buildSession(
        wordIds: [String],
        limit: Int,
        rotationSeed: Int
    ) -> [PracticeMixedQuizQuestion] {
        let pool = Array(Set(wordIds))
        guard !pool.isEmpty else { return [] }

        var generator = SeededRandomNumberGenerator(
            seed: StableSeed.fnv1a64("practice-quiz:\(rotationSeed)")
        )
        let total = min(max(1, limit), pool.count)
        var answers = pool.shuffled(using: &generator)
        if answers.count > total {
            answers = Array(answers.prefix(total))
        }

        return answers.enumerated().map { index, answer in
            let kind = kindRotation[index % kindRotation.count]
            let choiceCount = kind == .wordPickVideo ? 2 : 4
            let pick = PracticeChoiceBuilder.buildChoices(
                answer: answer,
                sessionPool: pool,
                choiceCount: choiceCount,
                generator: &generator
            )
            let moduleKind: ModuleStepKind = switch kind {
            case .watchChoose: .watchChoose
            case .translationChoose: .translationChoose
            case .wordPickVideo: .wordPickVideo
            }
            let wordLabel = ASLWordDisplay.title(for: answer)
            let prompt = ASLLessonPromptFraming.prompt(
                for: moduleKind,
                lessonId: "practice:\(rotationSeed)",
                stepIndex: index,
                wordId: answer,
                wordLabel: wordLabel
            )
            return PracticeMixedQuizQuestion(
                id: "\(rotationSeed)-\(index)-\(answer)-\(kind.rawValue)",
                kind: kind,
                answerWordId: pick.answerWordId,
                choices: pick.choices,
                prompt: prompt.isEmpty ? fallbackPrompt(for: kind, wordLabel: wordLabel) : prompt
            )
        }
    }

    static func rotationSeed(forDayKey dayKey: String, fingerprint: String) -> Int {
        StableSeed.fnv1a64("\(dayKey)|\(fingerprint)").hashValue
    }

    static func rotationSeed(forWordIds wordIds: [String]) -> Int {
        StableSeed.fnv1a64(wordIds.sorted().joined(separator: ",")).hashValue
    }

    private static func fallbackPrompt(
        for kind: PracticeQuizQuestionKind,
        wordLabel: String
    ) -> String {
        switch kind {
        case .watchChoose:
            return "What sign is this?"
        case .translationChoose:
            return "What does this sign mean?"
        case .wordPickVideo:
            return "Pick out \(wordLabel)."
        }
    }
}
