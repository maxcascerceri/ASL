//
//  SignVideoCard.swift
//  ASL
//
//  The single, app-wide "sign area" video card. Every page that shows a sign
//  or phrase video uses these shared metrics so the corner radius, shadow,
//  padding, and border are identical everywhere — the learner instantly knows
//  "that's the sign area." The primary card exposes the green turtle (slow-mo)
//  control; match-this-sign A/B cards reuse the turtle overlay per card.
//

import SwiftUI

/// One source of truth for the sign-video card chrome. Do not hardcode these
/// values elsewhere — reference these constants so every surface matches.
enum SignVideoCardMetrics {
    static let cornerRadius: CGFloat = 28
    static let innerPadding: CGFloat = 6
    static let borderWidth: CGFloat = 1
    /// Inner clip radius for the video layer inside the padded card.
    static var innerCornerRadius: CGFloat { cornerRadius - innerPadding }
}

/// Shared turtle (slow-mo) control overlaid on the primary sign card.
/// The turtle highlights green while the looping video is slowed down.
struct SignVideoControlsOverlay: View {
    @ObservedObject var controller: LessonPlayerController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                controlButton(systemName: "tortoise.fill", isActive: controller.isSlowMotionEnabled) {
                    controller.toggleSlowMotion()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private func controlButton(
        systemName: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.asl(15, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Brand.textPrimary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(isActive ? Color.lessonGreen : Color.white)
                )
                .overlay(
                    Circle().strokeBorder(Brand.divider.opacity(0.6), lineWidth: 1)
                )
                .elevation(.raisedControl(tint: Brand.ink, isPressed: false))
                .animation(.easeOut(duration: 0.18), value: isActive)
        }
        .buttonStyle(.plain)
    }
}
