//
//  ASLPremiumAccess.swift
//  ASL
//

import Foundation

enum ASLPremiumAccess {
    static let entitlementID = ASLSubscriptionStore.entitlementID
    static let onboardingStarEventId = "onboarding:microLesson"

    #if DEBUG
    private static let mockTrialKey = "asl.premium.mockTrialActive.v1"
    private static let debugReplayOnboardingKey = "asl.debug.replayOnboarding.v1"

    static var hasMockAccess: Bool {
        UserDefaults.standard.bool(forKey: mockTrialKey)
    }

    static var isDebugReplayOnboardingActive: Bool {
        UserDefaults.standard.bool(forKey: debugReplayOnboardingKey)
    }

    static func activateMockTrial() {
        UserDefaults.standard.set(true, forKey: mockTrialKey)
    }

    static func deactivateMockTrial() {
        UserDefaults.standard.removeObject(forKey: mockTrialKey)
    }

    static func beginDebugOnboardingReplay() {
        UserDefaults.standard.set(true, forKey: debugReplayOnboardingKey)
        NotificationCenter.default.post(name: ASLOnboarding.debugResetNotification, object: nil)
    }

    static func endDebugOnboardingReplay() {
        UserDefaults.standard.removeObject(forKey: debugReplayOnboardingKey)
        NotificationCenter.default.post(name: ASLOnboarding.debugResetNotification, object: nil)
    }
    #else
    static var isDebugReplayOnboardingActive: Bool { false }

    static func beginDebugOnboardingReplay() {}

    static func endDebugOnboardingReplay() {}
    #endif

    static func resetAll() {
        #if DEBUG
        deactivateMockTrial()
        #endif
        NotificationCenter.default.post(name: ASLOnboarding.debugResetNotification, object: nil)
    }
}
