//
//  ASLPremiumAccess.swift
//  ASL
//

import Foundation

protocol PremiumManaging {
    var hasAccess: Bool { get }
    func purchase(productId: String) async throws
    func restore() async throws
}

enum ASLPremiumAccess {
    static let mockTrialKey = "asl.premium.mockTrialActive.v1"
    static let onboardingStarEventId = "onboarding:microLesson"

    static var hasAccess: Bool {
        UserDefaults.standard.bool(forKey: mockTrialKey)
    }

    static func activateMockTrial() {
        UserDefaults.standard.set(true, forKey: mockTrialKey)
    }

    static func deactivateMockTrial() {
        UserDefaults.standard.removeObject(forKey: mockTrialKey)
    }

    static func resetAll() {
        deactivateMockTrial()
        NotificationCenter.default.post(name: ASLOnboarding.debugResetNotification, object: nil)
    }
}

/// Placeholder for future StoreKit 2 integration.
struct MockPremiumManager: PremiumManaging {
    var hasAccess: Bool { ASLPremiumAccess.hasAccess }

    func purchase(productId: String) async throws {
        ASLPremiumAccess.activateMockTrial()
    }

    func restore() async throws {
        // No-op until StoreKit is wired up.
    }
}
