//
//  MedalUnlockCelebrationView.swift
//  ASL
//

import SwiftUI

struct MedalUnlockCelebrationView: View {
    let definition: ASLMedalDefinition
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confettiIn = false
    @State private var medalIn = false
    @State private var headlineIn = false
    @State private var subheadIn = false
    @State private var buttonIn = false

    private var accent: Color {
        UnitPalette.medalPalette(for: definition).color
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if !reduceMotion {
                ConfettiCanvas(palette: accent)
                    .ignoresSafeArea()
                    .opacity(confettiIn ? 1 : 0)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                Text("Medal Unlocked!")
                    .font(.asl(32, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(headlineIn ? 1 : 0)
                    .offset(y: headlineIn ? 0 : 12)

                Text(definition.title)
                    .font(.asl(22, weight: .regular, design: .display))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .opacity(subheadIn ? 1 : 0)
                    .offset(y: subheadIn ? 0 : 10)

                ZStack {
                    ProfileMedalDisc(
                        state: .earned,
                        palette: UnitPalette.medalPalette(for: definition),
                        symbolName: definition.symbolName,
                        progressFraction: 1,
                        discSize: 128,
                        iconSize: 50
                    )
                }
                .padding(.vertical, 28)
                .scaleEffect(medalIn ? 1 : 0.72)
                .opacity(medalIn ? 1 : 0)

                if !definition.subtitle.isEmpty {
                    Text(definition.subtitle)
                        .font(.asl(16, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(subheadIn ? 1 : 0)
                }

                Spacer(minLength: 24)

                Button(action: continueTapped) {
                    Text("Continue")
                        .font(.asl(17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 18)
            }
        }
        .onAppear { runTimeline() }
    }

    private func continueTapped() {
        Haptics.tap()
        onContinue()
    }

    private func runTimeline() {
        Haptics.progressBump()
        withAnimation(.easeOut(duration: 0.35)) { confettiIn = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.66)) { medalIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.28)) { headlineIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.28)) { subheadIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.easeOut(duration: 0.28)) { buttonIn = true }
        }
    }
}
