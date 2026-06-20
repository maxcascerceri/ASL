//
//  LessonRouter.swift
//  ASL
//
//  Dispatches a lesson to the matching gameplay view based on `lesson.type`.
//  Owns the data preload (words + videos) so individual gameplay views can
//  assume content is ready and focus on interaction.
//

import SwiftUI

struct LessonRouter: View {
    let lesson: ASLLesson
    let unit: ASLUnit
    @ObservedObject var store: ASLDataStore

    var body: some View {
        Group {
            if lesson.type == .module || usesModuleSteps {
                ModuleLessonView(lesson: lesson, unit: unit, store: store)
            } else {
                UnknownLessonView(lesson: lesson)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: CustomTabBarHiddenPreferenceKey.self, value: true)
        .task(id: lesson.id) {
            store.beginLessonMediaSession(lessonId: lesson.id)
            store.loadWords(for: lesson)
            store.preloadStoneCascade(unit: unit, fromStoneSortOrder: lesson.sortOrder)
            store.preloadLessonMedia(lesson: lesson, unit: unit)
        }
        .onDisappear {
            store.endLessonMediaSession(lessonId: lesson.id)
        }
    }

    /// Deprecated lesson types with module `steps` still play through ModuleLessonView.
    private var usesModuleSteps: Bool {
        switch lesson.type {
        case .watchPick2, .watchPick4, .fillGap, .speed, .checkpoint:
            return !lesson.steps.isEmpty
        case .module, .unknown:
            return false
        }
    }
}

private struct UnknownLessonView: View {
    let lesson: ASLLesson

    var body: some View {
        ContentUnavailableView(
            "Coming soon",
            systemImage: "hammer.fill",
            description: Text("Lesson type \"\(lesson.type.rawValue)\" isn't wired up yet.")
        )
    }
}
