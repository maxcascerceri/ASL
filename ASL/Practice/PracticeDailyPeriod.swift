//
//  PracticeDailyPeriod.swift
//  ASL
//

import Foundation

/// Calendar-day boundaries for daily practice (resets at local midnight).
enum PracticeDailyPeriod {
    static func periodKey(for date: Date = .now) -> String {
        ProfileDayKey.dayKey(for: date)
    }

    static func makeSnapshot(tasks: [PracticeDailyTaskSpec]) -> PracticeDailyTasksSnapshot {
        PracticeDailyTasksSnapshot(
            periodKey: ProfileDayKey.today(),
            periodStartedAt: ProfileDayKey.startOfToday().timeIntervalSince1970,
            resetsAt: ProfileDayKey.endOfToday().timeIntervalSince1970,
            selectedTasks: tasks,
            progressByKey: [:],
            claimedTaskKeys: []
        )
    }

    static func isExpired(_ snapshot: PracticeDailyTasksSnapshot, now: Date = .now) -> Bool {
        periodKey(for: now) != snapshot.periodKey
    }
}
