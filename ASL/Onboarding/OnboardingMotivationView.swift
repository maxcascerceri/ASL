//
//  OnboardingMotivationView.swift
//  ASL
//

import SwiftUI

struct OnboardingMotivationView: View {
    let progress: Double
    @Binding var selections: [OnboardingMotivation]
    let onBack: () -> Void
    let onContinue: () -> Void

    private var bubbleText: String {
        if selections.isEmpty {
            return OnboardingCopy.motivationQuestion
        }
        if selections.count > 1 {
            return OnboardingCopy.motivationMultiSelectBubble
        }
        return OnboardingCopy.motivationReactiveBubble(selections[0])
    }

    private var bubbleBoldRanges: [String] {
        if selections.isEmpty {
            return OnboardingCopy.motivationQuestionBold
        }
        if selections.count > 1 {
            return OnboardingCopy.motivationMultiSelectBubbleBold
        }
        return OnboardingCopy.motivationReactiveBubbleBold(selections[0])
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingFlowProgressHeader(progress: progress, showsBack: true, onBack: onBack)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    OnboardingMascotHeader(
                        imageName: "sayings",
                        bubbleText: bubbleText,
                        boldRanges: bubbleBoldRanges,
                        bubbleAlignment: .center
                    )
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(OnboardingMotivation.allCases) { option in
                            OnboardingSelectionCard(
                                title: OnboardingCopy.motivationTitle(option),
                                symbolName: OnboardingCopy.motivationSymbol(option),
                                iconGradient: OnboardingSelectionStyle.motivationIconGradient(for: option),
                                isSelected: selections.contains(option),
                                action: { toggle(option) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            OnboardingPrimaryButton(
                title: OnboardingCopy.continueCTA,
                isEnabled: !selections.isEmpty,
                action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    private func toggle(_ option: OnboardingMotivation) {
        if let idx = selections.firstIndex(of: option) {
            selections.remove(at: idx)
        } else {
            let isFirstSelection = selections.isEmpty
            selections.append(option)
            if isFirstSelection {
                Haptics.progressBump()
            }
        }
    }
}
