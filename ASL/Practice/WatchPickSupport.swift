//
//  WatchPickSupport.swift
//  ASL
//
//  Shared watch-and-pick question builder for practice modes.
//

import Foundation

struct WatchPickQuestion: Identifiable, Hashable {
    let id: String
    let answerWordId: String
    let choices: [String]
}

enum WatchPickView {
    static func buildQuestions(
        wordIds: [String],
        choiceCount: Int,
        limit: Int
    ) -> [WatchPickQuestion] {
        let pool = Array(Set(wordIds))
        guard !pool.isEmpty else { return [] }
        let total = min(limit, pool.count)
        var generator = SystemRandomNumberGenerator()
        var answers = pool.shuffled(using: &generator)
        if answers.count > total {
            answers = Array(answers.prefix(total))
        }
        return answers.map { answer in
            var choices = Set([answer])
            for candidate in pool.shuffled(using: &generator) where choices.count < max(2, choiceCount) {
                choices.insert(candidate)
            }
            var choiceList = Array(choices)
            choiceList.shuffle(using: &generator)
            return WatchPickQuestion(
                id: answer,
                answerWordId: answer,
                choices: choiceList
            )
        }
    }

    static func buildQuestions(for lesson: ASLLesson, choiceCount: Int) -> [WatchPickQuestion] {
        buildQuestions(
            wordIds: lesson.wordIds,
            choiceCount: choiceCount,
            limit: lesson.wordIds.count
        )
    }
}
