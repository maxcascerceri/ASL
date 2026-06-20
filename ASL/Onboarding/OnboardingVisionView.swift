//
//  OnboardingVisionView.swift
//  ASL
//

import SwiftUI

private enum OnboardingVisionMetrics {
    /// Larger hero art; `mascotToHeadlineSpacing` is tuned so copy below stays put.
    static let heroMascotSize: CGFloat = 280
    static let mascotToHeadlineSpacing: CGFloat = -32
    static let headlineSize: CGFloat = 22
    static let subheadlineSize: CGFloat = 28
    static let unitMascotSize: CGFloat = 92
    static let unitTitleSize: CGFloat = 18
    static let unitRowCornerRadius: CGFloat = 14
    static let unitRowBorderWidth: CGFloat = 1
}

struct OnboardingVisionView: View {
    let profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void

    @State private var contentIn = false

    private var signsLearned: Int { profile.miniModuleSignsLearned ?? OnboardingMiniModuleSteps.signsLearnedCount }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingFlowProgressHeader(progress: progress)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Spacer()

            VStack(spacing: 0) {
                Image("doingthings")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: OnboardingVisionMetrics.heroMascotSize,
                        maxHeight: OnboardingVisionMetrics.heroMascotSize
                    )
                    .opacity(contentIn ? 1 : 0)
                    .scaleEffect(contentIn ? 1 : 0.9)

                VStack(spacing: 14) {
                    Text(headlineText)
                        .font(.asl(OnboardingVisionMetrics.headlineSize, weight: .regular))
                        .foregroundStyle(Brand.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Imagine what you'll know in 3 months!")
                        .font(.asl(OnboardingVisionMetrics.subheadlineSize, weight: .semibold, design: .display))
                        .foregroundStyle(Brand.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, OnboardingVisionMetrics.mascotToHeadlineSpacing)
                .opacity(contentIn ? 1 : 0)

                unitPreview
                    .padding(.top, 28)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 16)
            }

            Spacer()

            OnboardingPrimaryButton(title: OnboardingCopy.unlockPath, action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2)) {
                contentIn = true
            }
        }
    }

    private var headlineText: AttributedString {
        var result = AttributedString("In the last 60 seconds you learned ")
        result.font = .custom(ASLFontName.uiRegular, size: OnboardingVisionMetrics.headlineSize)
        result.foregroundColor = Brand.textPrimary

        var bold = AttributedString("\(signsLearned) signs")
        bold.font = .custom(ASLFontName.uiBold, size: OnboardingVisionMetrics.headlineSize)
        bold.foregroundColor = Brand.textPrimary

        var suffix = AttributedString(".")
        suffix.font = .custom(ASLFontName.uiRegular, size: OnboardingVisionMetrics.headlineSize)
        suffix.foregroundColor = Brand.textPrimary

        result.append(bold)
        result.append(suffix)
        return result
    }

    private var unitPreview: some View {
        let unitIds = OnboardingCopy.previewUnitIds(for: profile.motivations.first)
        return VStack(spacing: 10) {
            ForEach(unitIds, id: \.self) { unitId in
                HStack(spacing: 14) {
                    Image(UnitMascot.imageName(for: unitId) ?? "SignMascot")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: OnboardingVisionMetrics.unitMascotSize,
                            height: OnboardingVisionMetrics.unitMascotSize
                        )

                    Text(OnboardingCopy.previewUnitTitle(for: unitId))
                        .font(.asl(OnboardingVisionMetrics.unitTitleSize, weight: .semibold))
                        .foregroundStyle(Brand.textPrimary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: OnboardingVisionMetrics.unitRowCornerRadius,
                        style: .continuous
                    )
                    .fill(Brand.chrome)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: OnboardingVisionMetrics.unitRowCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        Brand.divider.opacity(0.9),
                        lineWidth: OnboardingVisionMetrics.unitRowBorderWidth
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
