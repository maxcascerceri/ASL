//
//  DictionaryMediaMetrics.swift
//  ASL
//
//  Production timing hooks for dictionary poster and first-frame latency.
//

import Foundation

final class DictionaryMediaMetrics {
    static let shared = DictionaryMediaMetrics()

    private(set) var timeToPosterMs: [String: Int] = [:]
    private(set) var timeToFirstFrameMs: [String: Int] = [:]

    private init() {}

    func recordPoster(wordId: String, milliseconds: Int) {
        timeToPosterMs[wordId] = milliseconds
    }

    func recordFirstFrame(wordId: String, milliseconds: Int, ready: Bool) {
        guard ready else { return }
        timeToFirstFrameMs[wordId] = milliseconds
    }
}
