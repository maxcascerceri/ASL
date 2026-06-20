//
//  OnboardingAppStoreReviewView.swift
//  ASL
//

import SwiftUI

private enum OnboardingAppStoreReviewMetrics {
    static let mascotSize: CGFloat = OnboardingMascotMetrics.standaloneMascotSize
    static let headlineSize: CGFloat = 36
    static let sublineSize: CGFloat = 28
}

private enum OnboardingAppStoreReviewMedia {
    static let mascotImageName = "mine and yours"
}

struct OnboardingAppStoreReviewView: View {
    var onAppearRequest: () -> Void = {}
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotIn = false
    @State private var copyIn = false
    @State private var buttonIn = false
    @State private var didRequestReview = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                mascotHero
                    .scaleEffect(mascotIn ? 1 : 0.92)
                    .opacity(mascotIn ? 1 : 0)

                headlineBlock
                    .opacity(copyIn ? 1 : 0)
                    .offset(y: copyIn ? 0 : 10)
            }
            .padding(.horizontal, 24)

            Spacer()

            OnboardingPrimaryButton(title: OnboardingCopy.continueCTA, action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .opacity(buttonIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(OnboardingCopy.appStoreReviewAccessibilityLabel)
        .onAppear {
            runAppearAnimation()
            requestReviewOnceOnAppear()
        }
    }

    private func requestReviewOnceOnAppear() {
        guard !didRequestReview else { return }
        didRequestReview = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onAppearRequest()
        }
    }

    private var mascotHero: some View {
        Image(OnboardingAppStoreReviewMedia.mascotImageName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: OnboardingAppStoreReviewMetrics.mascotSize,
                maxHeight: OnboardingAppStoreReviewMetrics.mascotSize
            )
            .frame(maxWidth: .infinity)
    }

    private var headlineBlock: some View {
        VStack(spacing: 8) {
            Text(OnboardingCopy.appStoreReviewHeadline)
                .font(.asl(OnboardingAppStoreReviewMetrics.headlineSize, weight: .bold, design: .display))
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.center)

            Text(sublineText)
                .font(.asl(OnboardingAppStoreReviewMetrics.sublineSize, weight: .regular, design: .display))
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private var sublineText: AttributedString {
        var result = AttributedString(OnboardingCopy.appStoreReviewSublinePrefix)
        result.font = .custom(ASLFontName.uiRegular, size: OnboardingAppStoreReviewMetrics.sublineSize)
        result.foregroundColor = Brand.textPrimary

        var bold = AttributedString(OnboardingCopy.appStoreReviewSublineBold)
        bold.font = .custom(ASLFontName.uiBold, size: OnboardingAppStoreReviewMetrics.sublineSize)
        bold.foregroundColor = OnboardingFlowProgressColor.bar

        result.append(bold)
        return result
    }

    private func runAppearAnimation() {
        if reduceMotion {
            mascotIn = true
            copyIn = true
            buttonIn = true
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
            mascotIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.25)) {
                copyIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.25)) {
                buttonIn = true
            }
        }
    }
}
