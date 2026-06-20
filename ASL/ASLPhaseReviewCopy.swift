//
//  ASLPhaseReviewCopy.swift
//  ASL
//

import Foundation

enum ASLPhaseReviewCopy {
    static let challengeQuestionCountMin = 16
    static let challengeQuestionCountMax = 24
    static let roundCount = 3

    /// Phase checkpoints are authored at 16–24 steps; use the live step total when known.
    static func questionCount(for stepTotal: Int) -> Int {
        guard stepTotal > 0 else { return challengeQuestionCountMin }
        return stepTotal
    }

    static func checkpointLabel(for phaseKey: String?) -> String {
        guard let phaseKey, !phaseKey.isEmpty else { return "Checkpoint" }
        return checkpointLabelsByPhaseKey[phaseKey] ?? "Checkpoint"
    }

    static func introHeadline(for phaseKey: String?) -> String {
        checkpointLabel(for: phaseKey)
    }

    static func completionBanner(for phaseKey: String?) -> String {
        "\(checkpointLabel(for: phaseKey)) Complete"
    }

    static func introSubtitle(phaseTitle: String) -> String {
        "Show what you remember from \(phaseTitle)."
    }

    static func completionHeadline(phaseTitle: String) -> String {
        "\(phaseTitle) complete"
    }

    static func skillsSummary(phaseKey: String, phaseTitle: String) -> String {
        skillsByPhaseKey[phaseKey]
            ?? "You strengthened your \(phaseTitle) vocabulary."
    }

    static func isMilestone(phaseKey: String?) -> Bool {
        phaseKey == "home_and_foundations"
    }

    static func isFinale(phaseKey: String?) -> Bool {
        phaseKey == "life_and_fluency"
    }

    private static let checkpointLabelsByPhaseKey: [String: String] = [
        "first_conversations": "Conversation Checkpoint",
        "daily_life": "Daily Life Checkpoint",
        "home_and_foundations": "Foundations Checkpoint",
        "describe_and_express": "Expression Checkpoint",
        "life_and_fluency": "Fluency Checkpoint",
    ]

    private static let skillsByPhaseKey: [String: String] = [
        "first_conversations": "You can now greet, respond, share feelings, introduce yourself, and talk about Deaf culture.",
        "daily_life": "You can describe everyday actions, get around, talk about time, family, and home.",
        "home_and_foundations": "You can talk about community life, count, fingerspell your name, and notice your surroundings.",
        "describe_and_express": "You can describe people and things, share feelings, and discuss work and the world.",
        "life_and_fluency": "You can chat about outdoors, hobbies, food, and everyday ASL sayings.",
        // Legacy phase keys (older Firestore documents)
        "people_and_actions": "You can meet people, talk about Deaf culture, and describe everyday actions.",
        "time_and_together": "You can get around, talk about time, family, friends, and celebrations.",
        "home_and_community": "You can talk about home, money, school, and your community.",
        "numbers_and_spelling": "You can count, fingerspell, and notice colors and routines at home.",
        "work_and_world": "You can discuss clothes, work, tech, countries, and animals.",
        "about_you": "You can meet people, ask questions, and talk about Deaf culture.",
        "social": "You can sign about friends, love, and holidays.",
        "essentials": "You can talk about home, money, school, and your community.",
        "foundations": "You know numbers, counting, and fingerspelling A through Z.",
        "describe_and_connect": "You can describe colors, sizes, feelings, and connect ideas.",
        "body_health": "You can discuss body parts, wellness, and feeling sick.",
        "work_and_style": "You can talk about clothes, accessories, and work life.",
        "tech_world": "You can navigate devices, apps, and countries.",
        "outdoors_fun": "You can chat about animals, weather, nature, sports, and hobbies.",
        "food": "You can sign fruits, veggies, meals, and drinks.",
        "everyday_wisdom": "You can express big ideas and everyday ASL sayings.",
        "time_family": "You can talk about time, days, and family relationships.",
        "alphabet_finish": "You can fingerspell your name and use the alphabet for names and new words.",
        "school_work_tech": "You can navigate school, work, and technology in ASL.",
        "travel_world": "You can discuss travel, directions, countries, and getting around.",
        "animals_nature": "You can talk about animals, plants, and the natural world.",
        "weather_sports_arts": "You can chat about weather, sports, music, and creative hobbies.",
        "food_expansion": "You can order food, discuss meals, and expand everyday vocabulary.",
        "big_ideas_expressions": "You can express abstract ideas, opinions, and common ASL sayings.",
    ]
}

enum PhaseReviewRound: CaseIterable, Equatable {
    case recognition
    case match
    case conversation

    var title: String {
        switch self {
        case .recognition: return "Recognition Round"
        case .match: return "Match Round"
        case .conversation: return "Conversation Round"
        }
    }

    var shortTitle: String {
        switch self {
        case .recognition: return "Recognition"
        case .match: return "Match"
        case .conversation: return "Conversation"
        }
    }

    var blurb: String {
        switch self {
        case .recognition:
            return "Spot the sign and pick the meaning."
        case .match:
            return "Pair each sign with its translation."
        case .conversation:
            return "Fill in the missing word in context."
        }
    }

    var icon: String {
        switch self {
        case .recognition: return "eye.fill"
        case .match: return "rectangle.on.rectangle.angled"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        }
    }

    static func round(for step: ModulePlayStep) -> PhaseReviewRound {
        switch step {
        case .watchChoose, .translationChoose:
            return .recognition
        case .matchPairs:
            return .match
        case .fillSlot, .signSequence, .phraseSlot:
            return .conversation
        default:
            return .recognition
        }
    }
}

struct PhaseReviewRoundPlan {
    struct RoundSlice {
        let round: PhaseReviewRound
        let stepIndices: [Int]
    }

    let slices: [RoundSlice]

    static func build(from steps: [ModulePlayStep]) -> PhaseReviewRoundPlan {
        var orderedRounds: [PhaseReviewRound] = []
        var indicesByRound: [PhaseReviewRound: [Int]] = [:]

        for (index, step) in steps.enumerated() {
            let round = PhaseReviewRound.round(for: step)
            if indicesByRound[round] == nil {
                orderedRounds.append(round)
            }
            indicesByRound[round, default: []].append(index)
        }

        let slices = orderedRounds.compactMap { round -> RoundSlice? in
            guard let indices = indicesByRound[round], !indices.isEmpty else { return nil }
            return RoundSlice(round: round, stepIndices: indices)
        }
        return PhaseReviewRoundPlan(slices: slices)
    }

    func round(at stepIndex: Int) -> PhaseReviewRound? {
        slices.first(where: { $0.stepIndices.contains(stepIndex) })?.round
    }

    func headerCaption(for stepIndex: Int) -> String? {
        guard let slice = slices.first(where: { $0.stepIndices.contains(stepIndex) }) else { return nil }
        let position = (slice.stepIndices.firstIndex(of: stepIndex) ?? 0) + 1
        return "\(slice.round.title) · \(position) of \(slice.stepIndices.count)"
    }

    func segmentFills(completedThrough stepIndex: Int) -> [Double] {
        slices.map { slice in
            let completed = slice.stepIndices.filter { $0 < stepIndex }.count
            return Double(completed) / Double(max(slice.stepIndices.count, 1))
        }
    }
}
