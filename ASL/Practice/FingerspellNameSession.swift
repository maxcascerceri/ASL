//
//  FingerspellNameSession.swift
//  ASL
//

import Combine
import Foundation

enum FingerspellSessionPhase: Equatable {
    case entry
    case intercept(SpellingInputClassification)
    case preview
    case learnLetter(index: Int)
    case flowPlayback
    case yourTurn
    case conversationBridge
    case complete
}

enum FingerspellSessionTrack: Equatable {
    case firstTime
    case returnVisit
}

struct FingerspellSessionStats: Equatable {
    var lettersPracticed: Int = 0
    var flowReplays: Int = 0
}

@MainActor
final class FingerspellNameSession: ObservableObject {
    @Published private(set) var entry: SavedFingerspellEntry
    @Published var phase: FingerspellSessionPhase
    @Published var stats = FingerspellSessionStats()
    @Published var learnIndex: Int = 0
    @Published var skipPerLetterYourTurn: Bool = true
    let track: FingerspellSessionTrack

    var letterWordIds: [String] { entry.letterWordIds }
    var displayText: String { entry.displayText }
    var letterCount: Int { entry.letterWordIds.count }
    var isReturnVisit: Bool { track == .returnVisit }

    var progress: Double {
        switch track {
        case .returnVisit:
            switch phase {
            case .flowPlayback: return 0.3
            case .yourTurn: return 0.65
            case .conversationBridge: return 0.9
            case .complete: return 1
            default: return 0.15
            }
        case .firstTime:
            switch phase {
            case .entry, .intercept:
                return 0
            case .preview:
                return 0.05
            case .learnLetter(let index):
                let span = 0.55
                let base = 0.1
                guard letterCount > 0 else { return base }
                return base + span * (Double(index + 1) / Double(letterCount))
            case .flowPlayback:
                return 0.7
            case .yourTurn:
                return 0.82
            case .conversationBridge:
                return 0.95
            case .complete:
                return 1
            }
        }
    }

    init(entry: SavedFingerspellEntry, track: FingerspellSessionTrack? = nil) {
        self.entry = entry
        let resolvedTrack = track ?? (entry.practiceCount > 0 ? .returnVisit : .firstTime)
        self.track = resolvedTrack
        self.phase = resolvedTrack == .returnVisit ? .flowPlayback : .preview
        self.learnIndex = 0
    }

    func beginLearning() {
        guard track == .firstTime else { return }
        learnIndex = 0
        phase = .learnLetter(index: 0)
    }

    func advanceFromLearn() {
        guard track == .firstTime else { return }
        stats.lettersPracticed = max(stats.lettersPracticed, learnIndex + 1)
        if learnIndex + 1 < letterCount {
            learnIndex += 1
            phase = .learnLetter(index: learnIndex)
        } else {
            phase = .flowPlayback
        }
    }

    func advanceFromFlow() {
        stats.flowReplays += 1
        phase = .yourTurn
    }

    func advanceFromYourTurn() {
        phase = .conversationBridge
    }

    func advanceFromBridge() {
        phase = .complete
    }

    func isDoubleLetter(at index: Int) -> Bool {
        guard index > 0, index < letterWordIds.count else { return false }
        return letterWordIds[index] == letterWordIds[index - 1]
    }
}
