//
//  OnboardingPrimaryButton.swift
//  ASL
//

import SwiftUI

private enum OnboardingPrimaryButtonMetrics {
    static let height: CGFloat = 56
    static let cornerRadius: CGFloat = 18
    static let depth: CGFloat = 5
    static let pressedFaceOffset: CGFloat = 3
    static let pressedDepthOffset: CGFloat = 1.5
    static let pressedScale: CGFloat = 0.985
}

struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var titleFontSize: CGFloat? = nil
    let action: () -> Void

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    private var showsPressed: Bool {
        isEnabled && (isPressed || releasePressed)
    }

    private var faceColor: Color {
        isEnabled ? Brand.primary : Brand.primary.opacity(0.45)
    }

    private var depthColor: Color {
        guard isEnabled else { return Brand.divider.opacity(0.45) }
        return PremiumCardStyle.softDepth(for: Brand.primary, mix: 0.34)
    }

    private var faceOffset: CGFloat {
        guard showsPressed else { return 0 }
        return OnboardingPrimaryButtonMetrics.pressedFaceOffset
    }

    private var depthOffset: CGFloat {
        guard isEnabled else { return 0 }
        return showsPressed
            ? OnboardingPrimaryButtonMetrics.pressedDepthOffset
            : OnboardingPrimaryButtonMetrics.depth
    }

    var body: some View {
        Group {
            if isEnabled {
                raisedButton
            } else {
                flatButton
            }
        }
        .animation(pressAnimation, value: showsPressed)
        .contentShape(Rectangle())
        .gesture(pressGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityRespondsToUserInteraction(isEnabled)
    }

    private var raisedButton: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: OnboardingPrimaryButtonMetrics.cornerRadius, style: .continuous)
                .fill(depthColor)
                .frame(height: OnboardingPrimaryButtonMetrics.height)
                .offset(y: depthOffset)

            RoundedRectangle(cornerRadius: OnboardingPrimaryButtonMetrics.cornerRadius, style: .continuous)
                .fill(faceColor)
                .frame(height: OnboardingPrimaryButtonMetrics.height)
                .overlay {
                    RoundedRectangle(cornerRadius: OnboardingPrimaryButtonMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    Text(title)
                        .font(.asl(titleFontSize ?? ASLTextMetrics.size(for: .button, variant: .standard), weight: .semibold))
                        .foregroundStyle(.white)
                }
                .offset(y: faceOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: OnboardingPrimaryButtonMetrics.height + OnboardingPrimaryButtonMetrics.depth,
            alignment: .top
        )
        .scaleEffect(showsPressed ? OnboardingPrimaryButtonMetrics.pressedScale : 1)
        .elevation(.raisedControl(tint: depthColor, isPressed: showsPressed))
    }

    private var flatButton: some View {
        Text(title)
            .font(.asl(titleFontSize ?? ASLTextMetrics.size(for: .button, variant: .standard), weight: .semibold))
            .foregroundStyle(Brand.secondaryLabel.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingPrimaryButtonMetrics.height)
            .background(
                RoundedRectangle(cornerRadius: OnboardingPrimaryButtonMetrics.cornerRadius, style: .continuous)
                    .fill(Brand.divider.opacity(0.65))
            )
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                if isEnabled {
                    state = true
                }
            }
            .onEnded { _ in
                guard isEnabled else { return }
                Haptics.tap()
                releasePressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    releasePressed = false
                }
                action()
            }
    }

    private var pressAnimation: Animation {
        showsPressed
            ? .easeOut(duration: 0.06)
            : .spring(response: 0.24, dampingFraction: 0.62)
    }
}
