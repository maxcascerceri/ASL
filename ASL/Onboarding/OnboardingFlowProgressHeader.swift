//
//  OnboardingFlowProgressHeader.swift
//  ASL
//

import SwiftUI

enum OnboardingFlowProgress {
    static func fraction(for step: OnboardingStep) -> Double {
        guard let index = OnboardingStep.progressSteps.firstIndex(of: step) else { return 0 }
        let total = Double(OnboardingStep.progressSteps.count)
        return Double(index + 1) / total
    }
}

struct OnboardingFlowProgressHeader: View {
    let progress: Double
    var animatesFill: Bool = true
    var showsBack: Bool = false
    var onBack: (() -> Void)? = nil
    var trailingAccessory: TrailingAccessory = .spacer

    enum TrailingAccessory {
        case spacer
        case close(() -> Void)
    }

    var body: some View {
        HStack(spacing: 12) {
            if showsBack, let onBack {
                backButton(action: onBack)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            progressBar

            switch trailingAccessory {
            case .spacer:
                Color.clear.frame(width: 36, height: 36)
            case .close(let action):
                Button(action: {
                    Haptics.tap()
                    action()
                }) {
                    Image(systemName: "xmark")
                        .font(.asl(14, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(Brand.chrome)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressBar: some View {
        PremiumProgressBarTrack(height: 12)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    PremiumProgressBarFill(
                        color: OnboardingFlowProgressColor.bar,
                        shadowColor: OnboardingFlowProgressColor.barShadow,
                        height: 12
                    )
                    .frame(width: max(14, geo.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 12)
            .frame(maxWidth: .infinity)
            .animation(animatesFill ? .easeInOut(duration: 0.35) : nil, value: progress)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Image(systemName: "chevron.left")
                .font(.asl(16, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(Brand.chrome.opacity(0.92))
                }
        }
        .buttonStyle(.plain)
    }
}

enum OnboardingFlowProgressColor {
    static let bar = Color(red: 0.96, green: 0.74, blue: 0.26)
    static let barShadow = Color(red: 0.88, green: 0.60, blue: 0.18)
}
