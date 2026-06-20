//
//  BundledSignMedia.swift
//  ASL
//
//  Resolves sign posters and videos shipped in the app bundle (BundledMedia/).
//

import Foundation

enum BundledSignMedia {
    private static let postersSubdirectory = "BundledMedia/Posters"
    private static let videosSubdirectory = "BundledMedia/Videos"
    static func posterURL(for wordId: String) -> URL? {
        let resolved = SignEquivalence.canonicalSignId(for: wordId)
        return resolveBundleURL(wordId: resolved, ext: "jpg", subdirectories: [
            postersSubdirectory,
            "BundledMedia/Posters",
            "Posters",
        ])
    }

    /// Raw read-only URL inside the app bundle (may not be AVPlayerLooper-safe).
    static func videoURL(for wordId: String) -> URL? {
        let resolved = SignEquivalence.canonicalSignId(for: wordId)
        resolveBundleURL(wordId: resolved, ext: "mp4", subdirectories: [
            videosSubdirectory,
            "BundledMedia/Videos",
            "Videos",
        ])
    }

    /// Writable cache path for AVPlayer (hot path: cache lookup only).
    static func playbackURL(for wordId: String) -> URL? {
        let resolved = SignEquivalence.canonicalSignId(for: wordId)
        return BundledPlaybackCache.cachedPlaybackURL(for: resolved)
            ?? BundledPlaybackCache.ensureCached(wordId: resolved)
    }

    static func hasBundledVideo(for wordId: String) -> Bool {
        videoURL(for: wordId) != nil
    }

    static func isPlayable(wordId: String) -> Bool {
        let resolved = SignEquivalence.canonicalSignId(for: wordId)
        return FilmedSignCatalog.isFilmed(wordId: resolved) && hasBundledVideo(for: resolved)
    }

    static var hasBundledPosters: Bool {
        !bundledPosterWordIds.isEmpty
    }

    static var bundledPosterWordIds: Set<String> {
        bundledWordIds(withExtension: "jpg", subdirectories: [
            postersSubdirectory,
            "BundledMedia/Posters",
            "Posters",
        ])
    }

    static var bundledVideoWordIds: Set<String> {
        bundledWordIds(withExtension: "mp4", subdirectories: [
            videosSubdirectory,
            "BundledMedia/Videos",
            "Videos",
        ])
    }

    private static func resolveBundleURL(
        wordId: String,
        ext: String,
        subdirectories: [String]
    ) -> URL? {
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(
                forResource: wordId,
                withExtension: ext,
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return Bundle.main.url(forResource: wordId, withExtension: ext)
    }

    private static func bundledWordIds(withExtension ext: String, subdirectories: [String]) -> Set<String> {
        for subdirectory in subdirectories {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) {
                return Set(urls.map { $0.deletingPathExtension().lastPathComponent })
            }
        }
        return []
    }

}
