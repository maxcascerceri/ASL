//
//  PracticeDailyDeepLink.swift
//  ASL
//

import Foundation

enum PracticeDailyDeepLink: Equatable {
    case practiceMode(PracticeSessionLaunch)
    case homePath
    case signsCategory(categoryId: String)
    case signsFavorites
}
