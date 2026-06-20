//
//  AppStoreReviewPrompt.swift
//  ASL
//

import StoreKit
import UIKit

enum AppStoreReviewPrompt {
    static let firstUnitOneStoneShownKey = "asl.appStoreReview.firstUnitOneStoneShown.v1"
    private static let legacyOnboardingShownKey = "asl.appStoreReview.onboardingShown.v1"

    static var shouldShowFirstUnitOneStonePrompt: Bool {
        if UserDefaults.standard.bool(forKey: firstUnitOneStoneShownKey) { return false }
        if UserDefaults.standard.bool(forKey: legacyOnboardingShownKey) { return false }
        return true
    }

    static func markFirstUnitOneStonePromptShown() {
        UserDefaults.standard.set(true, forKey: firstUnitOneStoneShownKey)
    }

    static func requestReviewIfPossible() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
    }
}
