//
//  DailyStreakCelebrationCopy.swift
//  ASL
//

import Foundation

/// Copy for calendar-day streak celebrations (main app + onboarding day streak).
enum DailyStreakCelebrationCopy {
    static func encouragement(newStreak: Int, continued: Bool) -> String {
        if newStreak <= 1 || !continued {
            return "Great start! Come back tomorrow to keep it going."
        }
        return "That's another day, keep it up!"
    }
}
