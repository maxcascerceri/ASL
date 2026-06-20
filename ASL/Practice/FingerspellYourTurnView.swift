//
//  FingerspellYourTurnView.swift
//  ASL
//

import SwiftUI

struct FingerspellYourTurnView: View {
    let entry: SavedFingerspellEntry
    @ObservedObject var store: ASLDataStore
    @ObservedObject var sequenceController: FingerspellSequenceController
    @Binding var phase: YourTurnPhase

    @StateObject private var camera = YourTurnCameraController()
    @StateObject private var pipController = LessonPlayerController()
    @StateObject private var playbackController = LessonPlayerController()

    var body: some View {
        Group {
            switch phase {
            case .watch:
                watchContent
            case .review:
                YourTurnReviewView(
                    referenceWordId: entry.letterWordIds.first ?? "a",
                    reviewPrompt: fingerspellReviewPrompt,
                    referenceController: pipController,
                    playbackController: playbackController,
                    recordedURL: camera.recordedURL,
                    store: store,
                    palette: PracticeTheme.accent,
                    onReRecord: {
                        camera.reset()
                        phase = .recording
                    },
                    sequenceController: sequenceController,
                    sequenceWordIds: entry.letterWordIds
                )
            case .recording:
                Color.clear
            }
        }
        .fullScreenCover(isPresented: recordingPresented) {
            YourTurnRecordingView(
                referenceWordId: entry.letterWordIds.first ?? "a",
                camera: camera,
                pipController: pipController,
                store: store,
                palette: PracticeTheme.accent,
                onClose: {
                    camera.reset()
                    phase = .watch
                },
                sequenceController: sequenceController,
                sequenceWordIds: entry.letterWordIds
            )
        }
        .onChange(of: camera.recordedURL) { _, url in
            guard url != nil, phase == .recording else { return }
            if let url {
                playbackController.load(url, wordId: nil)
                playbackController.replay()
            }
            phase = .review
        }
        .task(id: phase) {
            guard phase == .watch || phase == .review else { return }
            await sequenceController.playSequence(
                wordIds: entry.letterWordIds,
                store: store,
                loop: true
            )
        }
    }

    private var fingerspellReviewPrompt: ASLLessonPromptFraming.YourTurnReviewPrompt {
        ASLLessonPromptFraming.YourTurnReviewPrompt(
            headline: "Compare your spelling to the example.",
            subline: "Not quite right? Re-record and try again."
        )
    }

    private var recordingPresented: Binding<Bool> {
        Binding(
            get: { phase == .recording },
            set: { if !$0, phase == .recording { phase = .watch } }
        )
    }

    private var watchContent: some View {
        VStack(spacing: 16) {
            LessonPromptLabel(text: "Your turn")
                .padding(.top, 8)
            Text("Spell \(entry.displayText)")
                .font(LessonQuestionLayout.teachWordFont)
                .foregroundStyle(Brand.textPrimary)
            FingerspellSequenceVideoPlayer(
                controller: sequenceController,
                height: LessonQuestionLayout.videoHeight
            )
            FingerspellLetterChipStrip(
                letterWordIds: entry.letterWordIds,
                activeIndex: sequenceController.isPlayingSequence
                    ? sequenceController.currentLetterIndex
                    : nil,
                completedThrough: sequenceController.isPlayingSequence
                    ? max(0, sequenceController.currentLetterIndex - 1)
                    : nil
            )
            Text("Watch the flow, then record yourself spelling your name.")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }
}
