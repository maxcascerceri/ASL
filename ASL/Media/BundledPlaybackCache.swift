//
//  BundledPlaybackCache.swift
//  ASL
//
//  Copies bundled sign MP4s into a writable cache once so tap-time playback
//  never performs synchronous disk copies on the main actor.
//

import Foundation

enum BundledPlaybackCache {
    private static let cacheFolderName = "BundledSignVideos"
    private static let seedCompleteKey = "asl.bundledPlaybackCache.seeded.v1"

    static var isSeedComplete: Bool {
        UserDefaults.standard.bool(forKey: seedCompleteKey)
    }

    static var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appendingPathComponent(cacheFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Hot path — cache lookup only (no bundle copy).
    static func cachedPlaybackURL(for wordId: String) -> URL? {
        let destination = cacheDirectory.appendingPathComponent("\(wordId).mp4")
        guard fileExistsWithContent(destination) else { return nil }
        return destination
    }

    /// Ensures one sign is cached; used by warm pool / grid prefetch.
    @discardableResult
    static func ensureCached(wordId: String) -> URL? {
        if let cached = cachedPlaybackURL(for: wordId) {
            return cached
        }
        guard let bundleURL = BundledSignMedia.videoURL(for: wordId) else { return nil }
        return copyToCache(source: bundleURL, wordId: wordId)
    }

    /// Background seed of all bundled videos (~70 MB once per install).
    static func warmAllPlaybackFiles() async {
        if isSeedComplete,
           BundledSignMedia.bundledVideoWordIds.allSatisfy({ cachedPlaybackURL(for: $0) != nil }) {
            return
        }

        let wordIds = BundledSignMedia.bundledVideoWordIds.sorted()
        guard !wordIds.isEmpty else { return }

        await Task.detached(priority: .utility) {
            for wordId in wordIds {
                if Task.isCancelled { return }
                guard let bundleURL = BundledSignMedia.videoURL(for: wordId) else { continue }
                _ = copyToCache(source: bundleURL, wordId: wordId)
            }
        }.value

        UserDefaults.standard.set(true, forKey: seedCompleteKey)
        #if DEBUG
        print("[BundledPlaybackCache] seed complete (\(wordIds.count) videos)")
        #endif
    }

    static func warmPlaybackFiles(wordIds: [String]) async {
        let filmed = wordIds.filter { FilmedSignCatalog.isFilmed(wordId: $0) }
        guard !filmed.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for wordId in filmed {
                group.addTask {
                    _ = ensureCached(wordId: wordId)
                }
            }
        }
    }

    @discardableResult
    private static func copyToCache(source: URL, wordId: String) -> URL? {
        let destination = cacheDirectory.appendingPathComponent("\(wordId).mp4")
        if fileExistsWithContent(destination) {
            return destination
        }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            #if DEBUG
            print("[BundledPlaybackCache] copy failed \(wordId): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private static func fileExistsWithContent(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0 > 0
    }
}
