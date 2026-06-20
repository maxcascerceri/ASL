//
//  FingerspellLearnLetterView.swift
//  ASL
//

import SwiftUI

struct FingerspellLearnLetterView: View {
    let entry: SavedFingerspellEntry
    let letterIndex: Int
    @ObservedObject var store: ASLDataStore
    @ObservedObject var sequenceController: FingerspellSequenceController
    var isDoubleLetter: Bool

    var body: some View {
        VStack(spacing: 16) {
            LessonPromptLabel(text: prompt)
                .padding(.top, 8)
            FingerspellSequenceVideoPlayer(
                controller: sequenceController,
                height: LessonQuestionLayout.videoHeight,
                showsSlowMotionControl: true
            )
            FingerspellLetterChipStrip(
                letterWordIds: entry.letterWordIds,
                activeIndex: letterIndex,
                completedThrough: letterIndex > 0 ? letterIndex - 1 : nil,
                doubleLetterIndices: isDoubleLetter ? [letterIndex] : []
            )
            Text(tipCopy)
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .task(id: letterIndex) {
            let wordId = entry.letterWordIds[letterIndex]
            await sequenceController.loadLetter(wordId: wordId, store: store, loop: true)
        }
    }

    private var prompt: String {
        let letter = FingerspellLetterMapper.displayLabel(for: entry.letterWordIds[letterIndex])
        if isDoubleLetter {
            return "This is \(letter) again in \(entry.displayText)"
        }
        return "This is \(letter) in \(entry.displayText)"
    }

    private var tipCopy: String {
        if isDoubleLetter {
            return "Double letters often use a slight slide or bounce — don't freeze on one letter."
        }
        return "Letter \(letterIndex + 1) of \(entry.letterCount)"
    }
}
