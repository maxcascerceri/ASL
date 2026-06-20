//
//  LessonMediaPlanner.swift
//  ASL
//
//  Computes the full set of sign videos a stone may show, including distractors.
//

import Foundation

enum LessonMediaPlanner {
    static func allVideoWordIds(for lesson: ASLLesson, store: ASLDataStore, unit: ASLUnit) -> [String] {
        collectAllWordIds(for: lesson, store: store, unit: unit)
    }

    static func prioritizedWordIds(
        for lesson: ASLLesson,
        store: ASLDataStore,
        unit: ASLUnit,
        stepIndex: Int?
    ) -> [String] {
        let allIds = collectAllWordIds(for: lesson, store: store, unit: unit)
        guard let stepIndex, usesModulePipeline(lesson) else { return allIds }

        let steps = store.modulePlaySteps(for: lesson)
        guard !steps.isEmpty else { return allIds }
        var priority: [String] = []
        for offset in 0..<3 {
            let idx = stepIndex + offset
            guard steps.indices.contains(idx) else { break }
            priority.append(contentsOf: steps[idx].allReferencedWordIds)
        }
        return orderedUnique(priority + allIds)
    }

    /// Union of every word referenced in authored module steps.
    static func moduleMetadataWordIds(for lesson: ASLLesson) -> [String] {
        guard usesModulePipeline(lesson) else { return orderedUnique(lesson.wordIds) }

        var ids = lesson.wordIds
        for step in lesson.steps {
            if let wordId = step.wordId { ids.append(wordId) }
            if let answerWordId = step.answerWordId { ids.append(answerWordId) }
            if let comparisonWordId = step.comparisonWordId { ids.append(comparisonWordId) }
            ids.append(contentsOf: step.distractorWordIds)
            ids.append(contentsOf: step.pairWordIds)
            ids.append(contentsOf: step.sequenceWordIds)
            ids.append(contentsOf: step.questionWordIds)
        }
        return orderedUnique(ids)
    }

    private static func usesModulePipeline(_ lesson: ASLLesson) -> Bool {
        lesson.type == .module || !lesson.steps.isEmpty
    }

    private static func collectAllWordIds(
        for lesson: ASLLesson,
        store: ASLDataStore,
        unit: ASLUnit
    ) -> [String] {
        if usesModulePipeline(lesson) {
            let metadataIds = moduleMetadataWordIds(for: lesson)
            let steps = store.modulePlaySteps(for: lesson)
            let stepIds = steps.flatMap(\.allReferencedWordIds)
            return orderedUnique(stepIds + metadataIds)
        }
        return orderedUnique(lesson.wordIds)
    }

    private static func orderedUnique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }
}

extension ModulePlayStep {
    var allReferencedWordIds: [String] {
        switch self {
        case .teach(let item), .yourTurn(let item):
            return [item.wordId]
        case .aslTip(let item):
            return item.wordId.map { [$0] } ?? []
        case .watchChoose(let item), .translationChoose(let item):
            return [item.answerWordId]
        case .fillSlot(let item):
            return [item.answerWordId]
        case .wordPickVideo(let item):
            return item.choices
        case .signSequence(let item):
            return [item.phraseWordId] + item.sequenceWordIds
        case .phraseSlot(let item):
            return [item.phraseWordId] + item.sequenceWordIds + item.choices
        case .matchPairs(let item):
            return item.wordIds
        }
    }
}
