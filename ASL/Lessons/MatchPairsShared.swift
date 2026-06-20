//
//  MatchPairsShared.swift
//  ASL
//

import AVFoundation
import SwiftUI
import UIKit

struct MatchPairsItem: Identifiable {
    let id = UUID()
    let wordIds: [String]
    let prompt: String
}

enum MatchPairFlash: Equatable {
    case wrong(videoWordId: String, translationWordId: String)
    case correct(matchedWordId: String)
}

struct MatchPairMicrocopyBanner: View {
    let text: String
    let palette: Color

    var body: some View {
        Text(text)
            .font(LessonQuestionLayout.microcopyFont)
            .foregroundStyle(palette)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(palette.opacity(0.12), in: Capsule())
            .transition(.scale.combined(with: .opacity))
    }
}

/// Match-pairs layout: title + video at top, controls pinned just above the action tray.
struct MatchPairsStepLayout<Media: View, Controls: View>: View {
    let prompt: String
    /// Number of sign/word pairs on the board — up to four use a fixed video-to-controls gap.
    var pairCount: Int = 3
    @ViewBuilder var media: () -> Media
    @ViewBuilder var controls: () -> Controls

    private var usesCompactControlsPlacement: Bool {
        pairCount <= MatchPairLayout.compactPairCountThreshold
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: MatchPairLayout.sectionSpacing) {
                LessonPromptLabel(
                    text: prompt,
                    useInstructionWeight: true
                )
                media()
            }
            .frame(maxWidth: .infinity, alignment: .top)

            if usesCompactControlsPlacement {
                Color.clear
                    .frame(height: MatchPairLayout.compactVideoToControlsGap)
            } else {
                Spacer(minLength: 0)
            }

            controls()
                .padding(.bottom, MatchPairLayout.controlsBottomPadding)

            if usesCompactControlsPlacement {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

enum MatchPairLayout {
    static let sectionSpacing: CGFloat = 12
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 8
    static let wordTileMinWidth: CGFloat = 204
    static let wordTileHorizontalPadding: CGFloat = 34
    static let wordTileMinHeight: CGFloat = 58
    static let videoHeight: CGFloat = 232

    /// Uniform width for all word tiles in a match-pairs row, sized to the longest title.
    static func wordTileWidth(for titles: [String]) -> CGFloat {
        guard !titles.isEmpty else { return wordTileMinWidth }
        let font = chipUIFont
        let maxTextWidth = titles.map { title in
            (title as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return max(maxTextWidth + wordTileHorizontalPadding * 2, wordTileMinWidth)
    }

    private static var chipUIFont: UIFont {
        let size = LessonQuestionLayout.chipFontSize
        let weight: UIFont.Weight = LessonQuestionLayout.chipWeight == .bold ? .bold : .semibold
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    /// Boards with this many pairs or fewer use a fixed gap under the video so
    /// word/play rows align with the 2-pair layout instead of collapsing upward.
    static let compactPairCountThreshold: Int = 4
    static let compactVideoToControlsGap: CGFloat = 28
    /// Tight gap between the last play/word row and the bottom action tray.
    static let controlsBottomPadding: CGFloat = 4
}

enum MatchPairGridLayout {
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 10
    static let textCornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    /// Translation/word column vs sign-video column (must sum to `columnWidthDivisor`).
    static let columnWidthDivisor: Int = 5
    static let translationColumnSpan: Int = 2
    static let videoColumnSpan: Int = 3

    static func videoTileHeight(pairCount: Int) -> CGFloat {
        switch pairCount {
        case ...2: return 148
        case 3: return 120
        default: return 104
        }
    }

    static func textTileHeight(pairCount: Int) -> CGFloat {
        videoTileHeight(pairCount: pairCount)
    }
}

/// Two-column board: translation tiles on the left, inline sign videos on the right.
struct MatchPairTwoColumnBoard: View {
    let translationColumnOrder: [String]
    let videoColumnOrder: [String]
    let remainingWordIds: Set<String>
    let resolvedWordIds: Set<String>
    let selectedTranslationWordId: String?
    let selectedVideoWordId: String?
    let pairFlash: MatchPairFlash?
    let palette: Color
    let paletteShadow: Color
    @ObservedObject var store: ASLDataStore
    let wordTitle: (String) -> String
    let onSelectTranslation: (String) -> Void
    let onSelectVideo: (String) -> Void

    private var pairCount: Int {
        max(translationColumnOrder.count, videoColumnOrder.count)
    }

    private var rowCount: Int {
        min(translationColumnOrder.count, videoColumnOrder.count)
    }

    var body: some View {
        VStack(spacing: MatchPairGridLayout.rowSpacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(alignment: .center, spacing: MatchPairGridLayout.columnSpacing) {
                    let translationId = translationColumnOrder[row]
                    let videoId = videoColumnOrder[row]
                    let translationFlash = translationFlashStates(for: translationId)
                    let videoFlash = videoFlashStates(for: videoId)

                    MatchPairGridTextTile(
                        title: wordTitle(translationId),
                        palette: palette,
                        isSelected: selectedTranslationWordId == translationId,
                        isResolved: resolvedWordIds.contains(translationId),
                        flashWrong: translationFlash.wrong,
                        flashCorrect: translationFlash.correct,
                        height: MatchPairGridLayout.textTileHeight(pairCount: pairCount)
                    ) {
                        onSelectTranslation(translationId)
                    }
                    .containerRelativeFrame(
                        .horizontal,
                        count: MatchPairGridLayout.columnWidthDivisor,
                        span: MatchPairGridLayout.translationColumnSpan,
                        spacing: MatchPairGridLayout.columnSpacing
                    )
                    .disabled(!remainingWordIds.contains(translationId))

                    MatchPairGridVideoTile(
                        wordId: videoId,
                        palette: palette,
                        store: store,
                        isSelected: selectedVideoWordId == videoId,
                        isResolved: resolvedWordIds.contains(videoId),
                        flashWrong: videoFlash.wrong,
                        flashCorrect: videoFlash.correct,
                        height: MatchPairGridLayout.videoTileHeight(pairCount: pairCount)
                    ) {
                        onSelectVideo(videoId)
                    }
                    .containerRelativeFrame(
                        .horizontal,
                        count: MatchPairGridLayout.columnWidthDivisor,
                        span: MatchPairGridLayout.videoColumnSpan,
                        spacing: MatchPairGridLayout.columnSpacing
                    )
                    .disabled(!remainingWordIds.contains(videoId))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func translationFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch pairFlash {
        case .wrong(_, let translationWordId):
            return (translationWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }

    private func videoFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch pairFlash {
        case .wrong(let videoWordId, _):
            return (videoWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }
}

/// Translation tile for the two-column match grid.
struct MatchPairGridTextTile: View {
    let title: String
    let palette: Color
    let isSelected: Bool
    var isResolved: Bool = false
    var flashWrong: Bool = false
    var flashCorrect: Bool = false
    let height: CGFloat
    let action: () -> Void

    private var fillColor: Color {
        if isResolved { return Brand.neutralFill }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreen }
        return Color(.systemBackground)
    }

    private var textColor: Color {
        if flashWrong || flashCorrect { return .white }
        return Brand.textPrimary
    }

    private var strokeColor: Color {
        if isResolved { return Brand.neutralBorder }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreenShadow }
        if isSelected { return palette }
        return Brand.neutralBorder
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LessonQuestionLayout.chipFont)
                .foregroundStyle(textColor)
                .opacity(isResolved ? 0 : 1)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: MatchPairGridLayout.textCornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MatchPairGridLayout.textCornerRadius, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(isResolved)
        .opacity(isResolved ? 0.55 : 1)
        .accessibilityHidden(isResolved)
    }
}

/// Inline looping sign video for the match grid (one player per tile).
struct MatchPairGridVideoTile: View {
    let wordId: String
    let palette: Color
    @ObservedObject var store: ASLDataStore
    let isSelected: Bool
    var isResolved: Bool = false
    var flashWrong: Bool = false
    var flashCorrect: Bool = false
    let height: CGFloat
    let action: () -> Void

    @StateObject private var controller = LessonPlayerController()
    @State private var attachedWordId: String?

    private var strokeColor: Color {
        if isResolved { return Brand.neutralBorder }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreenShadow }
        if isSelected { return palette }
        return Brand.neutralBorder
    }

    private var showsVideoPlaceholder: Bool {
        ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store)
            || ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                videoLayer
                if !showsVideoPlaceholder {
                    SignVideoControlsOverlay(controller: controller)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: isSelected || flashWrong || flashCorrect ? 3 : 1.5)
            )
            .elevation(.insetField)
            .opacity(isResolved ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isResolved)
        .onAppear { ensureVideo() }
        .onChange(of: store.mediaCacheRevision) { _, _ in ensureVideo() }
        .onChange(of: store.videoPlaybackRevision) { _, _ in ensureVideo() }
        .onChange(of: wordId) { _, _ in ensureVideo() }
    }

    @ViewBuilder
    private var videoLayer: some View {
        if showsVideoPlaceholder {
            SignFilmPlaceholder(
                title: ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId),
                height: height,
                cornerRadius: SignVideoCardMetrics.cornerRadius,
                style: .choice
            )
        } else {
            LessonVideoPlayer(
                controller: controller,
                cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                videoGravity: .resizeAspectFill,
                placeholderColor: Brand.homeBackground
            )
            .padding(SignVideoCardMetrics.innerPadding)
            .background(Brand.homeBackground)
        }
    }

    private func ensureVideo() {
        attachedWordId = wordId
        guard store.hasPlayableVideo(for: wordId),
              !ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store),
              !ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) else {
            controller.detach()
            return
        }
        Task {
            await store.ensureVideoAttached(to: controller, wordId: wordId)
            guard attachedWordId == wordId else { return }
            controller.playAtNormalSpeed()
            controller.replay()
        }
    }
}

/// Play + translation columns for match-pairs steps.
struct MatchPairControlsRow<PlayTile: View, WordTile: View>: View {
    let wordColumnWidth: CGFloat
    @ViewBuilder var playColumn: () -> PlayTile
    @ViewBuilder var wordColumn: () -> WordTile

    var body: some View {
        HStack(alignment: .top, spacing: MatchPairLayout.columnSpacing) {
            VStack(spacing: MatchPairLayout.rowSpacing) {
                playColumn()
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(spacing: MatchPairLayout.rowSpacing) {
                wordColumn()
            }
            .frame(width: wordColumnWidth)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Sign column: play control only, compact width.
struct MatchPairPlayTile: View {
    let palette: Color
    let paletteShadow: Color
    let isSelected: Bool
    var isResolved: Bool = false
    var flashWrong: Bool = false
    var flashCorrect: Bool = false
    let accessibilitySignLabel: String
    let action: () -> Void

    private let side: CGFloat = 58

    private var fillColor: Color {
        if isResolved { return Brand.neutralFill }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreen }
        return Color.white
    }

    private var iconColor: Color {
        if flashWrong || flashCorrect { return .white }
        return palette
    }

    private var strokeColor: Color {
        if isResolved { return Brand.neutralBorder }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreenShadow }
        if isSelected { return palette }
        return Brand.neutralBorder
    }

    private var strokeWidth: CGFloat {
        2
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillColor)

                Image(systemName: "play.fill")
                    .font(.asl(LessonQuestionLayout.chipFontSize, weight: LessonQuestionLayout.chipWeight))
                    .foregroundStyle(iconColor)
                    .opacity(isResolved ? 0 : 1)
            }
            .frame(width: side, height: side)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(isResolved)
        .opacity(isResolved ? 0.55 : 1)
        .accessibilityLabel("Play sign, \(accessibilitySignLabel)")
        .accessibilityHidden(isResolved)
    }
}

/// Translation column: label text only.
struct MatchPairWordTile: View {
    let title: String
    let palette: Color
    let paletteShadow: Color
    let isSelected: Bool
    var isResolved: Bool = false
    var flashWrong: Bool = false
    var flashCorrect: Bool = false
    let action: () -> Void

    private var fillColor: Color {
        if isResolved { return Brand.neutralFill }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreen }
        return Color(.systemBackground)
    }

    private var textColor: Color {
        if flashWrong || flashCorrect { return .white }
        return Brand.textPrimary
    }

    private var strokeColor: Color {
        if isResolved { return Brand.neutralBorder }
        if flashWrong { return Color.lessonCoral }
        if flashCorrect { return Color.lessonGreenShadow }
        if isSelected { return palette }
        return Brand.neutralBorder
    }

    private var strokeWidth: CGFloat {
        2
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LessonQuestionLayout.chipFont)
                .foregroundStyle(textColor)
                .opacity(isResolved ? 0 : 1)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: MatchPairLayout.wordTileMinHeight)
                .padding(.horizontal, MatchPairLayout.wordTileHorizontalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                )
        }
        .buttonStyle(.plain)
        .disabled(isResolved)
        .opacity(isResolved ? 0.55 : 1)
        .accessibilityHidden(isResolved)
    }
}

enum MatchPairResolution {
    static func scheduleCorrectMatch(
        matchedWordId: String,
        isLastPair: Bool,
        setFlash: @escaping (MatchPairFlash?) -> Void,
        setLockTaps: @escaping (Bool) -> Void,
        clearSelection: @escaping () -> Void,
        removePair: @escaping () -> Void,
        onRoundContinues: @escaping () -> Void,
        onRoundComplete: @escaping () -> Void,
        storeWorkItem: @escaping (DispatchWorkItem?) -> Void
    ) {
        storeWorkItem(nil)
        setFlash(.correct(matchedWordId: matchedWordId))
        setLockTaps(true)
        Haptics.correct()
        LessonSounds.play(.correct)

        let removeWork = DispatchWorkItem {
            setFlash(nil)
            removePair()
            clearSelection()
            setLockTaps(false)

            if isLastPair {
                onRoundComplete()
            } else {
                onRoundContinues()
            }
            storeWorkItem(nil)
        }
        storeWorkItem(removeWork)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ASLMatchPairFeedback.correctFlashDuration,
            execute: removeWork
        )
    }
}

struct MatchPairsBoardView: View {
    let wordIds: [String]
    let prompt: String
    let palette: Color
    let paletteShadow: Color
    @ObservedObject var store: ASLDataStore
    @ObservedObject var playerController: LessonPlayerController
    let wordTitle: (String) -> String
    let onRoundComplete: () -> Void

    @State private var boardWordIds: [String] = []
    @State private var remainingWordIds: [String] = []
    @State private var resolvedWordIds: Set<String> = []
    @State private var playColumnOrder: [String] = []
    @State private var translationColumnOrder: [String] = []
    @State private var selectedVideoWordId: String?
    @State private var selectedTranslationWordId: String?
    @State private var lockTaps = false
    @State private var pairFlash: MatchPairFlash?
    @State private var feedbackWorkItem: DispatchWorkItem?
    @State private var attachedVideoWordId: String?

    var body: some View {
        MatchPairsStepLayout(prompt: prompt, pairCount: wordIds.count) {
            LessonVideoStage(
                controller: playerController,
                wordId: selectedVideoWordId,
                store: store,
                height: MatchPairLayout.videoHeight,
                placeholderColor: Brand.homeBackground,
                showsControls: true
            )
        } controls: {
            MatchPairControlsRow(
                wordColumnWidth: MatchPairLayout.wordTileWidth(
                    for: translationColumnOrder.map(wordTitle)
                )
            ) {
                ForEach(playColumnOrder, id: \.self) { wordId in
                    let flash = playFlashStates(for: wordId)
                    MatchPairPlayTile(
                        palette: palette,
                        paletteShadow: paletteShadow,
                        isSelected: selectedVideoWordId == wordId,
                        isResolved: resolvedWordIds.contains(wordId),
                        flashWrong: flash.wrong,
                        flashCorrect: flash.correct,
                        accessibilitySignLabel: wordTitle(wordId)
                    ) {
                        selectVideo(wordId)
                    }
                }
            } wordColumn: {
                ForEach(translationColumnOrder, id: \.self) { wordId in
                    let flash = translationFlashStates(for: wordId)
                    MatchPairWordTile(
                        title: wordTitle(wordId),
                        palette: palette,
                        paletteShadow: paletteShadow,
                        isSelected: selectedTranslationWordId == wordId,
                        isResolved: resolvedWordIds.contains(wordId),
                        flashWrong: flash.wrong,
                        flashCorrect: flash.correct
                    ) {
                        selectTranslation(wordId)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            resetBoard(with: wordIds)
        }
        .onChange(of: wordIds) { _, newValue in
            resetBoard(with: newValue)
        }
        .onChange(of: selectedVideoWordId) { _, newValue in
            guard newValue == nil, !remainingWordIds.isEmpty else { return }
            selectFirstAvailablePlayVideo()
        }
    }

    private func resetBoard(with ids: [String]) {
        boardWordIds = ids
        remainingWordIds = ids
        resolvedWordIds = []
        selectedTranslationWordId = nil
        pairFlash = nil
        feedbackWorkItem?.cancel()
        feedbackWorkItem = nil
        rebuildColumnOrders()
        selectFirstAvailablePlayVideo()
    }

    private func firstAvailablePlayWordId() -> String? {
        playColumnOrder.first { remainingWordIds.contains($0) }
    }

    private func selectFirstAvailablePlayVideo() {
        guard let wordId = firstAvailablePlayWordId() else { return }
        selectedVideoWordId = wordId
        ensureVideo(for: wordId)
    }

    private func maintainActivePlayVideo() {
        if let selected = selectedVideoWordId, remainingWordIds.contains(selected) {
            ensureVideo(for: selected)
            return
        }
        selectFirstAvailablePlayVideo()
    }

    private func playFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch pairFlash {
        case .wrong(let videoWordId, _):
            return (videoWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }

    private func translationFlashStates(for wordId: String) -> (wrong: Bool, correct: Bool) {
        switch pairFlash {
        case .wrong(_, let translationWordId):
            return (translationWordId == wordId, false)
        case .correct(let matchedId):
            return (false, matchedId == wordId)
        case .none:
            return (false, false)
        }
    }

    private func selectVideo(_ wordId: String) {
        guard remainingWordIds.contains(wordId), !lockTaps else { return }
        selectedVideoWordId = wordId
        Haptics.tap()
        ensureVideo(for: wordId)
        tryResolvePair()
    }

    private func selectTranslation(_ wordId: String) {
        guard remainingWordIds.contains(wordId), !lockTaps else { return }
        selectedTranslationWordId = wordId
        Haptics.tap()
        tryResolvePair()
    }

    private func tryResolvePair() {
        guard pairFlash == nil else { return }
        guard let videoWord = selectedVideoWordId,
              let translationWord = selectedTranslationWordId else { return }

        feedbackWorkItem?.cancel()

        if videoWord == translationWord {
            let matched = videoWord
            let isLastPair = remainingWordIds.count == 1

            MatchPairResolution.scheduleCorrectMatch(
                matchedWordId: matched,
                isLastPair: isLastPair,
                setFlash: { pairFlash = $0 },
                setLockTaps: { lockTaps = $0 },
                clearSelection: {
                    selectedTranslationWordId = nil
                },
                removePair: {
                    resolvedWordIds.insert(matched)
                    remainingWordIds.removeAll { $0 == matched }
                },
                onRoundContinues: {
                    selectFirstAvailablePlayVideo()
                },
                onRoundComplete: onRoundComplete,
                storeWorkItem: { feedbackWorkItem = $0 }
            )
        } else {
            Haptics.wrong()
            LessonSounds.play(.wrong)
            pairFlash = .wrong(videoWordId: videoWord, translationWordId: translationWord)
            lockTaps = true

            let work = DispatchWorkItem {
                pairFlash = nil
                selectedTranslationWordId = nil
                lockTaps = false
                maintainActivePlayVideo()
            }
            feedbackWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + ASLMatchPairFeedback.wrongFlashDuration,
                execute: work
            )
        }
    }

    private func rebuildColumnOrders() {
        let ids = boardWordIds
        guard !ids.isEmpty else {
            playColumnOrder = []
            translationColumnOrder = []
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
        playColumnOrder = play
        translationColumnOrder = translation
    }

    private func ensureVideo(for wordId: String) {
        attachedVideoWordId = wordId
        guard store.hasPlayableVideo(for: wordId),
              !ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store),
              !ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) else {
            playerController.detach()
            return
        }
        Task {
            await store.ensureVideoAttached(to: playerController, wordId: wordId)
            guard attachedVideoWordId == wordId else { return }
            playerController.playAtNormalSpeed()
            playerController.replay()
        }
    }
}
