//
//  OnboardingWelcomeView.swift
//  ASL
//

import AVFoundation
import SwiftUI

private enum OnboardingWelcomeMetrics {
    static let videoAspect: CGFloat = 9.0 / 16.0
    static let horizontalPadding: CGFloat = 20
    static let contentVerticalOffset: CGFloat = 36
    static let videoVerticalOffset: CGFloat = 16
    static let textTopPadding: CGFloat = 32
    static let textSpacing: CGFloat = 10
    static let footerBottomPadding: CGFloat = 24
    static let footerTopPadding: CGFloat = 16
    static let headlineTopFadeHeight: CGFloat = 160
    static let buttonDepth: CGFloat = 5
    static let headlineSize: CGFloat = 40
    static let subtitleSize: CGFloat = 18
    /// Fires once the launch splash clears and this screen is visible.
    static let welcomeHapticDelay: TimeInterval = 2.08
}

private enum OnboardingWelcomeMedia {
    static func videoURL() -> URL? {
        Bundle.main.url(
            forResource: "onboarding-welcome",
            withExtension: "mp4",
            subdirectory: "BundledMedia/Videos"
        )
    }
}

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @StateObject private var playerController = LessonPlayerController()

    var body: some View {
        GeometryReader { geo in
            let layout = WelcomeLayout(size: geo.size)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .top) {
                    welcomeVideo(size: layout.videoSize)
                        .frame(width: layout.videoSize.width, height: layout.videoSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .offset(y: OnboardingWelcomeMetrics.videoVerticalOffset)

                    headlineOverlay
                        .frame(width: layout.videoSize.width)
                        .padding(.top, OnboardingWelcomeMetrics.textTopPadding)
                }
                .offset(y: OnboardingWelcomeMetrics.contentVerticalOffset)

                Spacer(minLength: 0)

                OnboardingPrimaryButton(title: OnboardingCopy.getStarted, action: onContinue)
                    .padding(.horizontal, OnboardingWelcomeMetrics.horizontalPadding)
                    .padding(.top, OnboardingWelcomeMetrics.footerTopPadding)
                    .padding(.bottom, OnboardingWelcomeMetrics.footerBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            Color.white
                .ignoresSafeArea()
        }
        .onAppear {
            warmWelcomeVideo()
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingWelcomeMetrics.welcomeHapticDelay) {
                Haptics.progressBump()
            }
        }
        .onDisappear {
            playerController.pause()
        }
    }

    @ViewBuilder
    private func welcomeVideo(size: CGSize) -> some View {
        if OnboardingWelcomeMedia.videoURL() != nil {
            LessonVideoPlayer(
                controller: playerController,
                cornerRadius: 0,
                videoGravity: .resizeAspectFill,
                placeholderColor: Brand.soft
            )
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Brand.soft)
        }
    }

    private var headlineOverlay: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.72),
                    Color.white.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: OnboardingWelcomeMetrics.headlineTopFadeHeight)
            .allowsHitTesting(false)

            VStack(spacing: OnboardingWelcomeMetrics.textSpacing) {
                Text(OnboardingCopy.welcomeHeadline)
                    .font(.asl(OnboardingWelcomeMetrics.headlineSize, weight: .bold, design: .ui))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(OnboardingCopy.welcomeSub)
                    .font(.asl(OnboardingWelcomeMetrics.subtitleSize, weight: .regular, design: .ui))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, OnboardingWelcomeMetrics.horizontalPadding)
        }
    }

    private func warmWelcomeVideo() {
        guard let url = OnboardingWelcomeMedia.videoURL() else { return }
        Task {
            await playerController.loadLocal(url: url, wordId: "onboarding-welcome")
            playerController.playAtNormalSpeed()
        }
    }
}

private struct WelcomeLayout {
    let videoSize: CGSize

    init(size: CGSize) {
        let horizontalPadding = OnboardingWelcomeMetrics.horizontalPadding
        let footerHeight: CGFloat = 56
            + OnboardingWelcomeMetrics.buttonDepth
            + OnboardingWelcomeMetrics.footerTopPadding
            + OnboardingWelcomeMetrics.footerBottomPadding
        let maxWidth = max(0, size.width - horizontalPadding * 2)
        let maxHeight = max(0, size.height - footerHeight - 24)

        let heightAtFullWidth = maxWidth / OnboardingWelcomeMetrics.videoAspect
        if heightAtFullWidth <= maxHeight {
            videoSize = CGSize(width: maxWidth, height: heightAtFullWidth)
        } else {
            let width = maxHeight * OnboardingWelcomeMetrics.videoAspect
            videoSize = CGSize(width: width, height: maxHeight)
        }
    }
}
