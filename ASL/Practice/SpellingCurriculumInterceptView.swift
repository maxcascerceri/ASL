//
//  SpellingCurriculumInterceptView.swift
//  ASL
//

import SwiftUI

struct SpellingCurriculumInterceptView: View {
    let classification: SpellingInputClassification
    @ObservedObject var store: ASLDataStore
    let onLearnSign: (String) -> Void
    let onSpellAnyway: () -> Void
    let onPickDifferent: () -> Void

    private var wordId: String? {
        switch classification {
        case .curriculumWord(let wordId, _): return wordId
        case .acronym(let wordId, _): return wordId
        default: return nil
        }
    }

    private var isAcronym: Bool {
        if case .acronym = classification { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 36))
                .foregroundStyle(PracticeTheme.accent)
                .padding(.top, 12)

            VStack(spacing: 10) {
                Text(headline)
                    .font(LessonQuestionLayout.promptFont)
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                Text(bodyCopy)
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if let wordId {
                LessonVideoStage(
                    controller: previewController,
                    wordId: wordId,
                    store: store,
                    height: 180,
                    showsControls: false
                )
                .padding(.horizontal, 8)
                .task(id: wordId) {
                    await store.ensureVideoAttached(to: previewController, wordId: wordId)
                    previewController.playAtNormalSpeed()
                }
            }

            VStack(spacing: 12) {
                if let wordId {
                    PressableLessonPrimaryButton(
                        title: "Learn the sign",
                        color: PracticeTheme.accent,
                        depthColor: PracticeTheme.accentShadow
                    ) {
                        Haptics.tap()
                        onLearnSign(wordId)
                    }
                }

                if isAcronym || wordId != nil {
                    Button {
                        Haptics.tap()
                        onSpellAnyway()
                    } label: {
                        Text("Practice spelling anyway")
                            .font(.asl(.button, variant: .compact))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PracticeTheme.accent)
                }

                Button {
                    Haptics.tap()
                    onPickDifferent()
                } label: {
                    Text("Pick a different name")
                        .font(LessonQuestionLayout.subtitleFont)
                        .foregroundStyle(Brand.secondaryLabel)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }

    @StateObject private var previewController = LessonPlayerController()

    private var headline: String {
        let title = classification.displayText
        if isAcronym {
            return "\(title) has a sign in ASL"
        }
        return "\"\(title)\" has its own sign in ASL"
    }

    private var bodyCopy: String {
        if isAcronym {
            return "Signers also fingerspell it sometimes for emphasis — you can learn the sign or practice spelling."
        }
        return "Fingerspelling is usually for names and words without signs."
    }
}
