//
//  SpellingEntryView.swift
//  ASL
//

import SwiftUI

struct SpellingEntryView: View {
    @ObservedObject var store: ASLDataStore
    var initialText: String = ""
    var initialIntent: FingerspellNameIntent = .personalName
    let onSubmit: (SavedFingerspellEntry, SpellingInputClassification) -> Void
    let onCancel: () -> Void
    var registerTrayAction: ((@escaping () -> Void) -> Void)? = nil

    @State private var displayText: String = ""
    @State private var intent: FingerspellNameIntent = .personalName
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("What name do you want to fingerspell?")
                    .font(LessonQuestionLayout.promptFont)
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                Text("We'll walk you through each letter, then the full flow.")
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            Picker("Intent", selection: $intent) {
                ForEach(FingerspellNameIntent.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            TextField("Type a name", text: $displayText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.asl(22, weight: .semibold, design: .ui))
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Brand.homeBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Brand.divider.opacity(0.9), lineWidth: 1)
                )
                .focused($isFieldFocused)

            if let errorMessage {
                Text(errorMessage)
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            savedRoster

            Spacer(minLength: 0)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .onAppear {
            displayText = initialText
            intent = initialIntent
            registerTrayAction?({ submitFromTray() })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var savedRoster: some View {
        let entries = FingerspellNameStore.allEntries()
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Saved names")
                    .font(LessonQuestionLayout.microcopyFont)
                    .foregroundStyle(Brand.secondaryLabel)
                ForEach(entries.prefix(5)) { entry in
                    Button {
                        Haptics.tap()
                        resume(entry: entry)
                    } label: {
                        HStack {
                            Text(entry.displayText)
                                .font(LessonQuestionLayout.choiceFont)
                                .foregroundStyle(Brand.textPrimary)
                            Spacer()
                            if entry.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.aslReading(12, weight: .semibold))
                                    .foregroundStyle(PracticeTheme.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Brand.homeBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func submitFromTray() {
        errorMessage = nil
        switch CurriculumAwareSpellingResolver.resolve(displayText: displayText, intent: intent, store: store) {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let classification):
            switch classification {
            case .curriculumWord, .acronym:
                onSubmit(dummyEntry(from: classification), classification)
            default:
                guard var entry = CurriculumAwareSpellingResolver.makeEntry(
                    from: classification,
                    intent: intent,
                    isPinned: intent == .personalName && FingerspellNameStore.pinnedEntry() == nil
                ) else {
                    errorMessage = "Couldn't build spelling practice."
                    return
                }
                if intent == .personalName {
                    FingerspellNameStore.setPinned(id: entry.id)
                    entry.isPinned = true
                }
                entry = FingerspellNameStore.save(entry)
                onSubmit(entry, classification)
            }
        }
    }

    private func resume(entry: SavedFingerspellEntry) {
        let classification: SpellingInputClassification
        switch entry.intent {
        case .somethingElse:
            classification = .unknown(
                displayText: entry.displayText,
                spellingText: entry.spellingText,
                letterWordIds: entry.letterWordIds
            )
        default:
            classification = .personalName(
                displayText: entry.displayText,
                spellingText: entry.spellingText,
                letterWordIds: entry.letterWordIds
            )
        }
        onSubmit(entry, classification)
    }

    private func dummyEntry(from classification: SpellingInputClassification) -> SavedFingerspellEntry {
        SavedFingerspellEntry(
            id: UUID().uuidString,
            displayText: classification.displayText,
            spellingText: FingerspellLetterMapper.normalizedSpellingString(from: classification.displayText),
            letterWordIds: [],
            intent: intent,
            isPinned: false,
            createdAt: Date().timeIntervalSince1970,
            practiceCount: 0
        )
    }
}
