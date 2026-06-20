//
//  ProfileDayKey.swift
//  ASL
//

import Foundation

enum ProfileDayKey {
    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func today() -> String {
        dayKey(for: Date())
    }

    static func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    static func endOfToday() -> Date {
        let cal = Calendar.current
        let start = startOfToday()
        return cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
    }
}
