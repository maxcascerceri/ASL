//
//  WrongAnswerCoordinator.swift
//  ASL
//
//  Encodes the one rule each gameplay view needs to honour when the user taps
//  the wrong choice:
//
//  - Stones 1, 2, 3 (learning):   highlight the correct tile, slow-mo replay,
//                                  WAIT for them to re-tap the correct answer
//                                  before advancing. This buys one extra
//                                  retrieval event at the exact moment the
//                                  brain is asking for it.
//  - Stone 4 (assessment):         do NOT punish; auto-advance after a brief
//                                  reveal so the quiz keeps moving.
//

import Foundation

enum WrongAnswerPolicy {
    case forceRetap
    case autoAdvance(delayMs: Int)

    static func policy(for stone: ASLLessonType) -> WrongAnswerPolicy {
        switch stone {
        case .module, .watchPick2, .watchPick4, .fillGap, .speed:
            return .forceRetap
        case .checkpoint:
            return .autoAdvance(delayMs: 800)
        case .unknown:
            return .autoAdvance(delayMs: 800)
        }
    }
}
