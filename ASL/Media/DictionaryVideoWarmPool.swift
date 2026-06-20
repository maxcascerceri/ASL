//
//  DictionaryVideoWarmPool.swift
//  ASL
//
//  Pre-warms local dictionary sign videos so detail playback is instant on tap.
//

import Foundation

@MainActor
final class DictionaryVideoWarmPool {
    static let maxWarmControllers = 24
    static let categoryPrefetchCount = 12
    static let warmConcurrency = 6

    private var controllersByWordId: [String: LessonPlayerController] = [:]
    private var accessOrder: [String] = []
    private var protectedWordIds: Set<String> = []
    private var warmingWordIds: Set<String> = []

    func setProtectedWordIds(_ wordIds: Set<String>) {
        protectedWordIds = wordIds
    }

    func clearProtectedWordIds() {
        protectedWordIds = []
    }

    func warmPlaybackFiles(wordIds: [String]) async {
        await BundledPlaybackCache.warmPlaybackFiles(wordIds: wordIds)
    }

    func warmPlayer(wordId: String) async {
        guard FilmedSignCatalog.isFilmed(wordId: wordId) else { return }
        guard readyController(for: wordId) == nil else { return }
        guard !warmingWordIds.contains(wordId) else { return }

        warmingWordIds.insert(wordId)
        defer { warmingWordIds.remove(wordId) }

        guard let url = BundledPlaybackCache.ensureCached(wordId: wordId) else { return }

        let controller = LessonPlayerController()
        await controller.loadLocal(url: url, wordId: wordId)
        guard controller.isPlaybackReady, !controller.playbackFailed else { return }

        store(controller: controller, for: wordId)
    }

    func warmPlayers(wordIds: [String]) async {
        let targets = wordIds
            .filter { FilmedSignCatalog.isFilmed(wordId: $0) }
            .filter { readyController(for: $0) == nil }
        guard !targets.isEmpty else { return }

        let chunks = stride(from: 0, to: targets.count, by: Self.warmConcurrency).map {
            Array(targets[$0..<min($0 + Self.warmConcurrency, targets.count)])
        }

        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for wordId in chunk {
                    group.addTask { @MainActor in
                        await self.warmPlayer(wordId: wordId)
                    }
                }
            }
        }
    }

    func readyController(for wordId: String) -> LessonPlayerController? {
        guard let controller = controllersByWordId[wordId] else { return nil }
        guard controller.isPlaybackReady, !controller.playbackFailed else { return nil }
        touch(wordId)
        return controller
    }

    func borrowController(for wordId: String) async -> LessonPlayerController {
        if let ready = readyController(for: wordId) {
            return ready
        }

        await warmPlayer(wordId: wordId)
        if let ready = readyController(for: wordId) {
            return ready
        }

        let controller = LessonPlayerController()
        if let url = BundledPlaybackCache.ensureCached(wordId: wordId) {
            await controller.loadLocal(url: url, wordId: wordId)
            if controller.isPlaybackReady {
                store(controller: controller, for: wordId)
            }
        }
        return controller
    }

    private func store(controller: LessonPlayerController, for wordId: String) {
        if let existing = controllersByWordId[wordId], existing !== controller {
            evict(wordId: wordId)
        }
        controllersByWordId[wordId] = controller
        touch(wordId)
        trimIfNeeded()
    }

    private func touch(_ wordId: String) {
        accessOrder.removeAll { $0 == wordId }
        accessOrder.append(wordId)
    }

    private func evict(wordId: String) {
        controllersByWordId.removeValue(forKey: wordId)
        accessOrder.removeAll { $0 == wordId }
    }

    private func trimIfNeeded() {
        while controllersByWordId.count > Self.maxWarmControllers {
            guard let candidate = accessOrder.first(where: { !protectedWordIds.contains($0) }) else { break }
            evict(wordId: candidate)
        }
    }
}
