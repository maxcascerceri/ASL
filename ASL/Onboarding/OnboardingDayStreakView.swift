//
//  OnboardingDayStreakView.swift
//  ASL
//

import SwiftUI

struct OnboardingDayStreakView: View {
    let progress: Double
    let onContinue: () -> Void

    private var onboardingWeekDays: [ASLDataStore.StreakDayState] {
        let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        return weekdays.enumerated().map { idx, symbol in
            ASLDataStore.StreakDayState(
                index: idx,
                weekdaySymbol: symbol,
                isToday: idx == todayIndex,
                isActive: idx == todayIndex
            )
        }
    }

    var body: some View {
        DailyStreakCelebrationView(
            streakStart: 0,
            streakTarget: 1,
            weekDays: onboardingWeekDays,
            encouragement: DailyStreakCelebrationCopy.encouragement(newStreak: 1, continued: false),
            showsOnboardingHeader: true,
            progress: progress,
            continueTitle: OnboardingCopy.continueCTA,
            onContinue: onContinue
        )
    }
}
