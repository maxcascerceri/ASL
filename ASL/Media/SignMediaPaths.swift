//
//  SignMediaPaths.swift
//  ASL
//
//  Firebase Storage paths and quiz preload state for bundled sign media.
//

import Foundation

enum SignMediaCacheState: Equatable {
    case idle
    case syncing(ready: Int, total: Int)
    case ready
    case partial(ready: Int, total: Int)
    case failed
}

typealias QuizMediaCacheState = SignMediaCacheState

enum SignMediaPaths {
    static func videoStoragePath(wordId: String, fileExtension: String = "mov") -> String {
        "asl-videos/\(wordId)/video_001.\(fileExtension)"
    }

    static func posterStoragePath(wordId: String) -> String {
        "asl-videos/\(wordId)/poster_001.jpg"
    }

    /// Legacy 120px grid thumb.
    static func posterThumbStoragePath(wordId: String) -> String {
        "asl-videos/\(wordId)/poster_thumb_120.jpg"
    }

    /// Primary grid thumbnail (~30–50 KB, Retina-sharp).
    static func posterGridThumbStoragePath(wordId: String) -> String {
        "asl-videos/\(wordId)/poster_thumb_360.jpg"
    }
}
