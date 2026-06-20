//
//  LessonVideoChoices.swift
//  ASL
//

import AVFoundation
import SwiftUI

struct SelectableStackedVideoChoiceView: View {
    let wordIds: [String]
    let selectedWordId: String?
    var tileStates: [ChoiceTileState] = []
    @ObservedObject var store: ASLDataStore
    let height: CGFloat
    var palette: Color = .accentColor
    var paletteShadow: Color = .accentColor
    let onSelect: (Int, String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(wordIds.prefix(2).enumerated()), id: \.offset) { index, wordId in
                VideoChoiceCard(
                    wordId: wordId,
                    store: store,
                    height: height,
                    isSelected: selectedWordId == wordId,
                    feedbackState: tileStates.indices.contains(index) ? tileStates[index] : .rest,
                    selectionColor: palette,
                    selectionShadow: paletteShadow
                ) {
                    onSelect(index, wordId)
                }
            }
        }
    }
}

struct StackedVideoChoiceView: View {
    let wordIds: [String]
    @ObservedObject var store: ASLDataStore
    let height: CGFloat

    var body: some View {
        SelectableStackedVideoChoiceView(
            wordIds: wordIds,
            selectedWordId: nil,
            store: store,
            height: height
        ) { _, _ in }
    }
}

struct VideoChoiceCard: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    let height: CGFloat
    var isSelected: Bool = false
    var feedbackState: ChoiceTileState = .rest
    var selectionColor: Color = .accentColor
    var selectionShadow: Color = .accentColor
    var onTap: (() -> Void)?

    @StateObject private var controller = LessonPlayerController()
    @State private var attachedWordId: String?

    private var borderColor: Color {
        switch feedbackState {
        case .correct, .correctGlow:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        case .rest, .selected, .dimmed:
            return isSelected ? selectionColor : .clear
        }
    }

    private var borderWidth: CGFloat {
        switch feedbackState {
        case .correct, .wrong, .correctGlow:
            return 3.5
        case .rest, .selected, .dimmed:
            return isSelected ? 3 : 0
        }
    }

    private var showsVideoPlaceholder: Bool {
        ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store)
            || ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store)
    }

    var body: some View {
        cardBody
            .contentShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
            .onTapGesture {
                guard onTap != nil else { return }
                Haptics.tap()
                LessonSounds.play(.tap)
                onTap?()
            }
    }

    private var cardBody: some View {
        ZStack {
            videoLayer

            if !showsVideoPlaceholder {
                SignVideoControlsOverlay(controller: controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .elevation(.insetField)
        .lessonSignAreaLayoutStable()
        .onAppear { ensureVideo() }
        .onChange(of: wordId) { _, _ in ensureVideo() }
        .onChange(of: store.mediaCacheRevision) { _, _ in ensureVideo() }
        .onChange(of: store.videoPlaybackRevision) { _, _ in ensureVideo() }
        .onChange(of: store.wordsById.count) { _, _ in ensureVideo() }
        .onChange(of: store.videosByWordId.count) { _, _ in ensureVideo() }
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
