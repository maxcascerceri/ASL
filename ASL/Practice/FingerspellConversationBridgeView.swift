//
//  FingerspellConversationBridgeView.swift
//  ASL
//

import SwiftUI

struct FingerspellConversationBridgeView: View {
    let entry: SavedFingerspellEntry
    @ObservedObject var store: ASLDataStore
    @ObservedObject var phraseController: LessonPlayerController
    @ObservedObject var sequenceController: FingerspellSequenceController

    var body: some View {
        VStack(spacing: 16) {
            LessonPromptLabel(text: "Introduce yourself")
                .padding(.top, 8)
            Text("MY NAME IS + your name")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)

            LessonVideoStage(
                controller: phraseController,
                wordId: "mynameis",
                store: store,
                height: 160,
                showsControls: true
            )

            Text("MY NAME IS")
                .font(LessonQuestionLayout.chipFont)
                .foregroundStyle(Brand.textPrimary)

            FingerspellSequenceVideoPlayer(
                controller: sequenceController,
                height: 140
            )

            FingerspellLetterChipStrip(
                letterWordIds: entry.letterWordIds,
                completedThrough: entry.letterCount - 1
            )

            Text("Hold briefly after your name — give them time to read it.")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .task {
            await store.ensureVideoAttached(to: phraseController, wordId: "mynameis")
            phraseController.playAtNormalSpeed()
            try? await Task.sleep(nanoseconds: 800_000_000)
            await sequenceController.playSequence(
                wordIds: entry.letterWordIds,
                store: store
            )
        }
    }
}
