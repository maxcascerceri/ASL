//
//  OnboardingStreakGoalView.swift
//  ASL
//

import SwiftUI

private struct StreakGoalOption: Identifiable {
    let days: Int
    let descriptor: String
    var id: Int { days }
}

private let streakGoalOptions: [StreakGoalOption] = [
    .init(days: 7, descriptor: "Strong start"),
    .init(days: 14, descriptor: "Clearly committed"),
    .init(days: 30, descriptor: "Unstoppable streak"),
    .init(days: 50, descriptor: "Incredible dedication"),
]

struct OnboardingStreakGoalView: View {
    let progress: Double
    @Binding var selection: Int?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingFlowProgressHeader(progress: progress)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    OnboardingMascotHeader(
                        imageName: UnitMascot.headAndFaceImageName,
                        bubbleText: OnboardingCopy.streakGoalBubble,
                        boldRanges: OnboardingCopy.streakGoalBubbleBold,
                        bubbleAlignment: .center
                    )
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(streakGoalOptions) { option in
                            OnboardingSelectionCard(
                                title: "\(option.days) day streak",
                                subtitle: option.descriptor,
                                layout: .splitRow,
                                isSelected: selection == option.days,
                                action: { selection = option.days }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            OnboardingPrimaryButton(
                title: "I'm committed",
                isEnabled: selection != nil,
                action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            if selection == nil { selection = 7 }
        }
    }
}
