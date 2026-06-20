//
//  FingerspellFlowPlaybackView.swift
//  ASL
//

import SwiftUI

struct FingerspellFlowPlaybackView: View {
    let entry: SavedFingerspellEntry
    @ObservedObject var store: ASLDataStore
    @ObservedObject var sequenceController: FingerspellSequenceController
    let onFinished: () -> Void

    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 16) {
            LessonPromptLabel(text: "Watch the full spelling")
                .padding(.top, 8)
            Text(entry.displayText)
                .font(LessonQuestionLayout.teachWordFont)
                .foregroundStyle(Brand.textPrimary)
            FingerspellSequenceVideoPlayer(
                controller: sequenceController,
                height: LessonQuestionLayout.videoHeight
            )
            FingerspellLetterChipStrip(
                letterWordIds: entry.letterWordIds,
                activeIndex: sequenceController.isPlayingSequence ? sequenceController.currentLetterIndex : nil,
                completedThrough: sequenceController.isPlayingSequence
                    ? max(0, sequenceController.currentLetterIndex - 1)
                    : entry.letterCount - 1
            )
            Text("Smooth and steady beats rushed.")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)
            Button {
                Haptics.tap()
                Task {
                    didFinish = false
                    await sequenceController.replaySequence(store: store)
                }
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
                    .font(LessonQuestionLayout.choiceFont)
                    .foregroundStyle(PracticeTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .task {
            await sequenceController.playSequence(
                wordIds: entry.letterWordIds,
                store: store
            )
        }
        .onChange(of: sequenceController.isPlayingSequence) { _, playing in
            guard !playing, !didFinish else { return }
            didFinish = true
            onFinished()
        }
    }
}
