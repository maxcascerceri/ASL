//
//  SignYourTurnPracticeView.swift
//  ASL
//
//  Your Turn-style camera practice from the Signs dictionary detail sheet.
//

import SwiftUI

struct SignYourTurnPracticeView: View {
    @ObservedObject var store: ASLDataStore
    let wordId: String
    let onDismiss: () -> Void

    @State private var yourTurnPhase: YourTurnPhase = .watch
    @State private var navigationButton: ModuleNavigationButtonState = .ready("Record now")

    private static let palette = Brand.primary
    private static let paletteShadow = Color(red: 0.20, green: 0.44, blue: 0.70)

    var body: some View {
        LessonShell(
            progress: 0.12,
            palette: Self.palette,
            paletteShadow: Self.paletteShadow,
            leaveConfirmMessage: "You can leave practice anytime.",
            onLeave: onDismiss,
            reservesActionTraySpace: true
        ) {
            ZStack(alignment: .bottom) {
                YourTurnStepView(
                    lessonId: "signs:\(wordId)",
                    referenceWordId: wordId,
                    title: "Your Turn",
                    prompt: SignYourTurnPracticeCopy.watchPrompt,
                    phase: $yourTurnPhase,
                    store: store,
                    palette: Self.palette,
                    paletteShadow: Self.paletteShadow
                )
                .padding(.bottom, LessonActionTrayLayout.contentInsetAboveTray(for: navigationButton))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if yourTurnPhase != .recording {
                    LessonActionTray(
                        state: navigationButton,
                        palette: Self.palette,
                        paletteShadow: Self.paletteShadow,
                        action: tappedNavigationButton
                    )
                }
            }
        }
        .onAppear { syncTray(for: yourTurnPhase) }
        .onChange(of: yourTurnPhase) { _, phase in
            if phase == .recording {
                navigationButton = .ready("Record now")
            }
            syncTray(for: phase)
        }
        .task(id: wordId) {
            store.loadWords(wordIds: [wordId])
        }
    }

    private func syncTray(for phase: YourTurnPhase) {
        switch phase {
        case .watch:
            navigationButton = .ready("Record now")
        case .review:
            navigationButton = .ready("Submit")
        case .recording:
            break
        }
    }

    private func tappedNavigationButton() {
        guard navigationButton.isEnabled else { return }

        switch yourTurnPhase {
        case .watch:
            yourTurnPhase = .recording
        case .recording:
            break
        case .review:
            if case .correct = navigationButton {
                Haptics.correct()
                LessonSounds.play(.correct)
                onDismiss()
                return
            }

            Haptics.correct()
            LessonSounds.play(.correct)
            navigationButton = .correct(
                headline: SignYourTurnPracticeCopy.affirmation(for: wordId),
                actionTitle: "Done"
            )
        }
    }
}

private enum SignYourTurnPracticeCopy {
    private static let affirmations = [
        "Nice signing — keep it up!",
        "Great job putting yourself on camera.",
        "Love the effort. You're building real muscle memory.",
        "Strong work — that's how fluency grows.",
    ]

    static let watchPrompt = "Watch the example, then record yourself signing it."

    static func affirmation(for wordId: String) -> String {
        let index = abs(wordId.hashValue) % affirmations.count
        return affirmations[index]
    }
}
