//
//  OnboardingSplashView.swift
//  ASL
//

import SwiftUI

private enum OnboardingSplashMetrics {
    static let displayDuration: TimeInterval = 2
    static let imageName = "onboarding-splash"
    /// Source art sits slightly right of center; nudge fill crop so the mascot reads centered on device.
    static func horizontalShift(for size: CGSize) -> CGFloat {
        -size.width * 0.015
    }
}

/// Full-screen launch splash shown on every cold start.
struct OnboardingSplashView: View {
    let onFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Image(OnboardingSplashMetrics.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(x: OnboardingSplashMetrics.horizontalShift(for: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingSplashMetrics.displayDuration) {
                onFinished()
            }
        }
    }
}
