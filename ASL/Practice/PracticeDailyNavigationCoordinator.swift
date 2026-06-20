//
//  PracticeDailyNavigationCoordinator.swift
//  ASL
//

import Combine
import Foundation

@MainActor
final class PracticeDailyNavigationCoordinator: ObservableObject {
    @Published var pendingDeepLink: PracticeDailyDeepLink?
    @Published var activeTaskInstanceKey: String?
    @Published var shouldReturnToPractice = false
    @Published var highlightedTaskInstanceKey: String?

    @Published var consumeHomePath = false
    @Published var consumeSignsCategoryId: String?
    @Published var consumeSignsFavorites = false
    @Published var consumePracticeLaunch: PracticeSessionLaunch?

    func beginTask(instanceKey: String, deepLink: PracticeDailyDeepLink) {
        activeTaskInstanceKey = instanceKey
        pendingDeepLink = deepLink
        shouldReturnToPractice = true
        highlightedTaskInstanceKey = nil
    }

    func routePendingDeepLink() {
        guard let link = pendingDeepLink else { return }
        pendingDeepLink = nil
        switch link {
        case .homePath:
            consumeHomePath = true
        case .signsCategory(let categoryId):
            consumeSignsCategoryId = categoryId
        case .signsFavorites:
            consumeSignsFavorites = true
        case .practiceMode(let launch):
            consumePracticeLaunch = launch
        }
    }

    func acknowledgeHomePathConsumed() {
        consumeHomePath = false
    }

    func acknowledgeSignsCategoryConsumed() {
        consumeSignsCategoryId = nil
    }

    func acknowledgeSignsFavoritesConsumed() {
        consumeSignsFavorites = false
    }

    func acknowledgePracticeLaunchConsumed() {
        consumePracticeLaunch = nil
    }

    func taskCompleted(instanceKey: String) {
        highlightedTaskInstanceKey = instanceKey
        shouldReturnToPractice = true
        pendingDeepLink = nil
    }

    func acknowledgeReturnToPractice() {
        shouldReturnToPractice = false
        activeTaskInstanceKey = nil
    }

    func clearHighlight() {
        highlightedTaskInstanceKey = nil
    }
}