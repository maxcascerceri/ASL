//
//  ProfileSettingsSheet.swift
//  ASL
//

import SwiftUI

struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Brand.divider)
                .frame(width: 42, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)

            Text("Settings")
                .font(.asl(24, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                settingsLink(title: "Contact Us", url: ASLLegalLinks.contactUs)
                Divider().padding(.leading, 24)
                settingsLink(title: "Privacy Policy", url: ASLLegalLinks.privacyPolicy)
                Divider().padding(.leading, 24)
                settingsLink(title: "Terms of Use", url: ASLLegalLinks.termsOfUse)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Brand.chrome)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Brand.divider, lineWidth: 1.5)
            }
            .padding(.horizontal, 24)

            #if DEBUG
            Button("Reset onboarding") {
                ASLOnboarding.resetAll()
                ASLPremiumAccess.beginDebugOnboardingReplay()
                dismiss()
            }
            .font(.asl(15, weight: .semibold))
            .foregroundStyle(Brand.primary)
            .padding(.top, 16)

            if ASLPremiumAccess.isDebugReplayOnboardingActive {
                Text("Onboarding preview is active — use Exit preview in the app or finish the flow.")
                    .font(.asl(13, weight: .medium))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            #endif

            Spacer(minLength: 0)
        }
        .brandCanvasBackground()
    }

    private func settingsLink(title: String, url: URL?) -> some View {
        Button {
            Haptics.tap()
            if let url {
                openURL(url)
            }
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.asl(17, weight: .medium))
                    .foregroundStyle(Brand.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
