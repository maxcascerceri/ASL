//
//  ASLTipStepView.swift
//  ASL
//
//  Lightweight, non-graded "ASL Tip" step. Shows a helpful learning tip and,
//  when provided, a contextual sign/phrase video using the shared sign card.
//

import Foundation
import SwiftUI

struct ASLTipStepView: View {
    let item: ASLTipItem
    @ObservedObject var store: ASLDataStore
    let palette: Color
    let paletteShadow: Color

    @StateObject private var controller = LessonPlayerController()
    @State private var attachedWordId: String?

    var body: some View {
        VStack(spacing: LessonQuestionLayout.sectionSpacing) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.opacity(0.16))
                        .frame(width: 64, height: 64)
                    Image(systemName: "lightbulb.fill")
                        .font(.asl(28, weight: .semibold))
                        .foregroundStyle(palette)
                }
                Text("ASL TIP")
                    .font(.asl(13, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(palette)
            }

            Text(item.text)
                .font(LessonQuestionLayout.promptFont)
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, LessonQuestionLayout.horizontalPadding)

            if let wordId = item.wordId {
                LessonVideoStage(
                    controller: controller,
                    wordId: wordId,
                    store: store,
                    height: LessonQuestionLayout.videoHeightCompact,
                    showsControls: true
                )
                .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { attachVideoIfNeeded() }
        .onChange(of: store.mediaCacheRevision) { _, _ in attachVideoIfNeeded() }
        .onChange(of: store.videosByWordId.count) { _, _ in attachVideoIfNeeded() }
    }

    private func attachVideoIfNeeded() {
        guard let wordId = item.wordId else { return }
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

// MARK: - Tip catalog (generated from scripts/asl_tips_catalog.py — keep in sync)

enum ASLTipCatalog {
    struct Tip: Hashable {
        let id: String
        let text: String
        let wordId: String?
    }

    static let all: [Tip] = [
        Tip(id: "listen-watch-face", text: "When someone's signing to you, watch their face — eyebrows and expression tell you a lot.", wordId: "face"),
        Tip(id: "sign-match-face", text: "Let your face match what you're signing — a happy sign needs a happy face.", wordId: "imhappy"),
        Tip(id: "sign-say-no", text: "Saying no? Shake your head as you sign — your face and hands work together.", wordId: "no"),
        Tip(id: "sign-no-mouthing", text: "Skip mouthing the English word under your sign — your mouth is part of the sign.", wordId: "translate"),
        Tip(id: "sign-clear-face", text: "Keep your hands off your mouth while signing so people can read your expression.", wordId: "mouth"),
        Tip(id: "sign-zone", text: "Keep signs in front of your chest — not down in your lap or up by your chin.", wordId: "body"),
        Tip(id: "sign-one-hand", text: "Stick with one signing hand — switching mid-sign makes you harder to follow.", wordId: "practice"),
        Tip(id: "sign-slow-wins", text: "Slow and clean beats fast and sloppy — speed comes once the sign feels natural.", wordId: "signslow"),
        Tip(id: "sign-record-yourself", text: "Record yourself and watch it back — you'll spot things you miss in the mirror.", wordId: "camera"),
        Tip(id: "sign-location", text: "Same handshape, different spot on your body — often a completely different word.", wordId: "different"),
        Tip(id: "fs-steady-rhythm", text: "Fingerspell in a steady rhythm — smooth flow beats racing through letters.", wordId: "fingerspell"),
        Tip(id: "fs-lax-hand", text: "Keep a relaxed hand — tension makes letters blur together.", wordId: "fingerspell"),
        Tip(id: "fs-double-letters", text: "Double letters? Slide or bounce slightly instead of holding the same shape twice.", wordId: "letter"),
        Tip(id: "fs-locations", text: "Keep fingerspelling near shoulder height in a small area — don't let it drift down.", wordId: "fingerspell"),
        Tip(id: "questions-eyebrows", text: "Yes/no question? Raise your eyebrows. Who, what, or where? Lower them.", wordId: "what"),
        Tip(id: "space-people", text: "Place each person in a spot in space — then point back there for he, she, or they.", wordId: "they"),
        Tip(id: "space-quote", text: "Quoting someone? Turn toward them, sign their words, then turn back.", wordId: "talk"),
        Tip(id: "space-direction", text: "Signs like give and tell move toward whoever receives them — aim the action.", wordId: "give"),
        Tip(id: "grammar-time-first", text: "Words like today and tomorrow usually come first in the sentence.", wordId: "today"),
        Tip(id: "grammar-finish-thought", text: "Done with your thought? Hold the last sign, then lower your hands.", wordId: "stop"),
        Tip(id: "meet-get-attention", text: "Need someone's attention? Wave, tap their shoulder, or flick the lights.", wordId: "meet"),
        Tip(id: "meet-one-at-a-time", text: "One person signs at a time — wait for a pause before you jump in.", wordId: "wait"),
        Tip(id: "meet-rephrase", text: "Sign didn't land? Try a different sign or shorter phrase — not just spelling faster.", wordId: "howyousignthat"),
        Tip(id: "meet-sorry", text: "Walked through two people signing? A quick sorry smooths it over.", wordId: "excuseme"),
        Tip(id: "meet-two-hands", text: "Set the coffee down — two free hands show the full sign.", wordId: "tablet"),
        Tip(id: "meet-interpreter", text: "With an interpreter, look at and talk to the Deaf person — not the interpreter.", wordId: "interpreter"),
        Tip(id: "listen-stay-with-them", text: "While they sign, nod and stay engaged — it shows you're following along.", wordId: "ok"),
        Tip(id: "listen-speak-up", text: "Lost the thread? Ask again or show you're confused — pretending hurts both of you.", wordId: "idontunderstand"),
        Tip(id: "sign-look-at-them", text: "When you sign, look at their face — not down at your own hands.", wordId: "see"),
        Tip(id: "meet-on-camera", text: "On video or in person, face the light and frame yourself chest-up with both hands visible.", wordId: "video"),
        Tip(id: "sign-voice-or-hands", text: "Pick signing or speaking — doing both at once is tough for others to follow.", wordId: "signlanguage"),
        Tip(id: "pronoun-i-me", text: "I and me use the same sign — point to yourself. English uses two words; ASL uses one.", wordId: "i"),
        Tip(id: "pronoun-we-us", text: "We and us share one sign — point toward your group in space.", wordId: "we"),
        Tip(id: "pronoun-he-him", text: "He and him are the same sign — point to where you set up that person.", wordId: "he"),
        Tip(id: "pronoun-she-her", text: "She and her share one sign — point back to her spot in space.", wordId: "she"),
        Tip(id: "pronoun-they-them", text: "They and them use the same sign — point to that group in space.", wordId: "they"),
        Tip(id: "pronoun-my-mine", text: "My and mine are the same possessive sign toward yourself.", wordId: "my"),
        Tip(id: "pronoun-your-yours", text: "Your and yours share one possessive sign toward the other person.", wordId: "your"),
        Tip(id: "pronoun-our-ours", text: "Our and ours use the same possessive sign toward your group.", wordId: "our"),
    ]

    private static let byId: [String: Tip] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func tip(for id: String) -> Tip? {
        byId[id]
    }

    /// Curriculum tip, or the next unseen tip when the learner already saw this one.
    static func resolve(curriculumTipId: String?, curriculumText: String, seenIds: Set<String>) -> Tip {
        if let curriculumTipId,
           !seenIds.contains(curriculumTipId),
           let match = tip(for: curriculumTipId) {
            return match
        }
        if let curriculumTipId,
           let match = tip(for: curriculumTipId),
           seenIds.contains(curriculumTipId) {
            if let unseen = all.first(where: { !seenIds.contains($0.id) }) {
                return unseen
            }
            return match
        }
        if let unseen = all.first(where: { !seenIds.contains($0.id) }) {
            return unseen
        }
        if let curriculumTipId, let match = tip(for: curriculumTipId) {
            return match
        }
        let trimmed = curriculumText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let fallbackWordId = curriculumTipId.flatMap { tip(for: $0)?.wordId }
            return Tip(id: curriculumTipId ?? "legacy", text: trimmed, wordId: fallbackWordId)
        }
        return all[0]
    }
}
