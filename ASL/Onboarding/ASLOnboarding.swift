//
//  ASLOnboarding.swift
//  ASL
//

import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable, Codable {
    case splash
    case welcome
    case ziggyIntro
    case motivation
    case dailyGoal
    case loading
    case miniModule
    case lessonComplete
    case appStoreReview
    case dayStreak
    case streakGoal
    case threeMonthVision
    case scienceFact
    case paywall

    var id: Int { rawValue }

    static let progressSteps: [OnboardingStep] = [
        .motivation,
        .dailyGoal,
        .loading,
        .miniModule,
        .lessonComplete,
        .dayStreak,
        .streakGoal,
        .threeMonthVision,
        .scienceFact,
        .paywall,
    ]

    var progressIndex: Int? {
        Self.progressSteps.firstIndex(of: self)
    }
}

enum OnboardingMotivation: String, Codable, CaseIterable, Identifiable {
    case family
    case work
    case education
    case deaf
    case connecting
    case fun

    var id: String { rawValue }
}

struct OnboardingProfile: Codable, Equatable {
    var motivations: [OnboardingMotivation] = []
    var dailyMinutes: Int?
    var streakGoal: Int?
    var completedMiniModule: Bool = false
    var miniModuleScore: Int?
    var miniModuleSignsLearned: Int?
    /// Last onboarding screen reached — used to resume after an interrupted session.
    var lastReachedStep: OnboardingStep?

    static let empty = OnboardingProfile()
}

enum ASLOnboarding {
    private static let profileKey = "asl.onboarding.profile.v2"
    static let completedKey = "asl.onboarding.completed.v1"
    private static let hasLaunchedKey = "asl.app.hasLaunched.v1"

    static let debugResetNotification = Notification.Name("asl.onboarding.debugReset")

    /// True after the app has been opened at least once (including interrupted first sessions).
    static var hasLaunchedBefore: Bool {
        if UserDefaults.standard.bool(forKey: hasLaunchedKey) { return true }
        if isComplete { return true }
        if loadProfile() != .empty { return true }
        return false
    }

    static func markLaunchedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasLaunchedKey) else { return }
        UserDefaults.standard.set(true, forKey: hasLaunchedKey)
    }

    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    static func loadProfile() -> OnboardingProfile {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(OnboardingProfile.self, from: data) else {
            return .empty
        }
        return profile
    }

    static func saveProfile(_ profile: OnboardingProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    /// Picks up onboarding where the user left off.
    static func resumeStep(for profile: OnboardingProfile) -> OnboardingStep {
        if let saved = profile.lastReachedStep {
            if saved == .splash {
                return .welcome
            }
            if saved == .appStoreReview {
                return .dayStreak
            }
            // Pre–science-fact builds stored paywall at raw value 12 (now scienceFact).
            if saved == .scienceFact && isComplete {
                return .paywall
            }
            return saved
        }
        return inferredResumeStep(for: profile)
    }

    private static func inferredResumeStep(for profile: OnboardingProfile) -> OnboardingStep {
        if profile.completedMiniModule {
            if profile.streakGoal != nil {
                return .threeMonthVision
            }
            return .streakGoal
        }
        if profile.dailyMinutes != nil {
            return .miniModule
        }
        if !profile.motivations.isEmpty {
            return .dailyGoal
        }
        return .welcome
    }

    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: "asl.onboarding.profile.v1")
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: hasLaunchedKey)
        NotificationCenter.default.post(name: debugResetNotification, object: nil)
    }
}
