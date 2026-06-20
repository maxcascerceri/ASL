//
//  ASLSettings.swift
//  ASL
//

import Foundation

enum ASLLegalLinks {
    private static let pagesBase = URL(string: "https://maxcascerceri.github.io/ASL/")!

    static let contactUs = URL(string: "mailto:maxcascerceri@verizon.net")
    static let privacyPolicy = pagesBase.appendingPathComponent("privacy.html")
    static let termsOfUse = pagesBase.appendingPathComponent("terms.html")
    static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

enum ASLSettings {
    private static let hapticsKey = "asl.settings.hapticsEnabled"
    private static let soundsKey = "asl.settings.lessonSoundsEnabled"

    static var hapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: hapticsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: hapticsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    static var lessonSoundsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: soundsKey) == nil { return false }
            return UserDefaults.standard.bool(forKey: soundsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: soundsKey) }
    }
}

enum PracticeSignSprintHighScore {
    private static let storageKey = "asl.practice.signSprint.highScore.v1"

    static var best: Int {
        UserDefaults.standard.integer(forKey: storageKey)
    }

    struct RegistrationResult {
        let highScore: Int
        let isNewRecord: Bool
    }

    @discardableResult
    static func register(score: Int) -> RegistrationResult {
        let previous = best
        guard score > previous else {
            return RegistrationResult(highScore: previous, isNewRecord: false)
        }
        UserDefaults.standard.set(score, forKey: storageKey)
        return RegistrationResult(highScore: score, isNewRecord: true)
    }
}
