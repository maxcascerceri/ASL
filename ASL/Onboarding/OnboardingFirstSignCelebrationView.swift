//
//  OnboardingFirstSignCelebrationView.swift
//  ASL
//

import SwiftUI

private enum OnboardingFirstSignCelebrationMetrics {
    static let mascotSize: CGFloat = 310
    static let bubbleFontSize: CGFloat = 21
    static let sublineSize: CGFloat = 19
    static let sublineRowSpacing: CGFloat = 6
    static let buttonFontSize: CGFloat = 18
}

struct OnboardingFirstSignCelebrationView: View {
    let wordDisplayTitle: String
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confettiIn = false
    @State private var mascotIn = false
    @State private var mascotReadyBump = false
    @State private var bubbleIn = false
    @State private var sublineIn = false
    @State private var buttonIn = false
    @State private var didContinue = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if !reduceMotion {
                ConfettiCanvas(palette: Brand.primary, style: .subtleStreak)
                    .ignoresSafeArea()
                    .opacity(confettiIn ? 1 : 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image("abcs4")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: OnboardingFirstSignCelebrationMetrics.mascotSize,
                            maxHeight: OnboardingFirstSignCelebrationMetrics.mascotSize
                        )
                        .scaleEffect(mascotDisplayScale)
                        .opacity(mascotIn ? 1 : 0)

                    MascotSpeechBubble(
                        text: OnboardingCopy.firstSignCelebrationBubble(word: wordDisplayTitle),
                        boldRanges: [wordDisplayTitle],
                        tailDirection: .top,
                        fontSize: OnboardingFirstSignCelebrationMetrics.bubbleFontSize
                    )
                    .opacity(bubbleIn ? 1 : 0)
                    .offset(y: bubbleIn ? 0 : 12)

                    VStack(spacing: OnboardingFirstSignCelebrationMetrics.sublineRowSpacing) {
                        Text(OnboardingCopy.firstSignCelebrationSublinePrimary)
                            .font(.asl(OnboardingFirstSignCelebrationMetrics.sublineSize, weight: .semibold))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)

                        Text(OnboardingCopy.firstSignCelebrationSublineSecondary)
                            .font(.asl(OnboardingFirstSignCelebrationMetrics.sublineSize, weight: .semibold))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .opacity(sublineIn ? 1 : 0)
                    .offset(y: sublineIn ? 0 : 8)
                }
                .padding(.horizontal, 20)

                Spacer()

                OnboardingPrimaryButton(
                    title: OnboardingCopy.continueCTA,
                    titleFontSize: OnboardingFirstSignCelebrationMetrics.buttonFontSize,
                    action: continueOnce
                )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .opacity(buttonIn ? 1 : 0)
                    .offset(y: buttonIn ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: continueOnce)
        .onAppear {
            runCelebrationTimeline()
        }
    }

    private var mascotDisplayScale: CGFloat {
        if !mascotIn { return 0.85 }
        if mascotReadyBump { return 1.02 }
        return 1
    }

    private func runCelebrationTimeline() {
        if reduceMotion {
            mascotIn = true
            bubbleIn = true
            sublineIn = true
            buttonIn = true
            Haptics.correct()
            return
        }

        Haptics.correct()

        withAnimation(.easeOut(duration: 0.15)) {
            confettiIn = true
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            mascotIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.32)) {
                bubbleIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.28)) {
                sublineIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.28)) {
                buttonIn = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                mascotReadyBump = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    mascotReadyBump = false
                }
            }
        }
    }

    private func continueOnce() {
        guard buttonIn, !didContinue else { return }
        didContinue = true
        Haptics.tap()
        onContinue()
    }
}
