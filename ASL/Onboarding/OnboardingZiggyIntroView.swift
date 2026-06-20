//
//  OnboardingZiggyIntroView.swift
//  ASL
//

import SwiftUI

struct OnboardingZiggyIntroView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotIn = false
    @State private var bubbleIn = false
    @State private var didAdvance = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image("abcs4")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: OnboardingMascotMetrics.standaloneMascotSize,
                        maxHeight: OnboardingMascotMetrics.standaloneMascotSize
                    )
                    .scaleEffect(mascotIn ? 1 : 0.85)
                    .opacity(mascotIn ? 1 : 0)

                MascotSpeechBubble(
                    text: OnboardingCopy.ziggyIntroBubble,
                    boldRanges: OnboardingCopy.ziggyIntroBubbleBold,
                    tailDirection: .top
                )
                .opacity(bubbleIn ? 1 : 0)
                .offset(y: bubbleIn ? 0 : 12)
            }
            .padding(.horizontal, 20)

            Spacer()

            OnboardingPrimaryButton(title: OnboardingCopy.continueCTA, action: finishOnce)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .opacity(bubbleIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: finishOnce)
        .onAppear {
            runIntroTimeline()
        }
    }

    private func runIntroTimeline() {
        if reduceMotion {
            mascotIn = true
            bubbleIn = true
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            mascotIn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.32)) {
                bubbleIn = true
            }
        }
    }

    private func finishOnce() {
        guard !didAdvance else { return }
        didAdvance = true
        Haptics.tap()
        onFinished()
    }
}
