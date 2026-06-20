//
//  MediaBootstrapMetrics.swift
//  ASL
//

import Foundation

@MainActor
final class MediaBootstrapMetrics {
    static let shared = MediaBootstrapMetrics()

    private(set) var bundleSeedMilliseconds: Int?
    private(set) var bootstrapQueueDepth: Int = 0

    func recordBundleSeed(milliseconds: Int) {
        bundleSeedMilliseconds = milliseconds
        #if DEBUG
        print("[MediaBootstrap] bundle seed \(milliseconds)ms")
        #endif
    }

    func setQueueDepth(_ depth: Int) {
        bootstrapQueueDepth = depth
    }
}
