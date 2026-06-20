//
//  OnboardingDailyGoalView.swift
//  ASL
//

import SwiftUI

private enum DailyGoalOption: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20

    var id: Int { rawValue }

    var title: String { "\(rawValue) minutes / day" }

    var descriptor: String {
        switch self {
        case .five: return "Casual"
        case .ten: return "Regular"
        case .fifteen: return "Serious"
        case .twenty: return "Intense"
        }
    }

    var signProjection: Int {
        OnboardingCopy.dailyGoalWeeklyProjection(for: rawValue)
    }
}

struct OnboardingDailyGoalView: View {
    let progress: Double
    @Binding var selection: Int?
    let onBack: () -> Void
    let onContinue: () -> Void

    private var selectedOption: DailyGoalOption? {
        guard let sel = selection else { return nil }
        return DailyGoalOption(rawValue: sel)
    }

    private var bubbleText: String {
        guard let opt = selectedOption else {
            return OnboardingCopy.dailyGoalQuestion
        }
        return OnboardingCopy.dailyGoalReactiveBubble(signCount: opt.signProjection)
    }

    private var boldRanges: [String] {
        guard let opt = selectedOption else {
            return OnboardingCopy.dailyGoalQuestionBold
        }
        return OnboardingCopy.dailyGoalReactiveBubbleBold(signCount: opt.signProjection)
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
                        imageName: "time",
                        bubbleText: bubbleText,
                        boldRanges: boldRanges
                    )
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(DailyGoalOption.allCases) { option in
                            OnboardingSelectionCard(
                                title: option.title,
                                subtitle: option.descriptor,
                                layout: .splitRow,
                                isSelected: selection == option.rawValue,
                                action: { selection = option.rawValue }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            OnboardingPrimaryButton(
                title: OnboardingCopy.continueCTA,
                isEnabled: selection != nil,
                action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
