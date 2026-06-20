//
//  PosterImageView.swift
//  ASL
//
//  Dictionary grid poster: disk cache first, 360px HTTPS thumb second.
//

import SwiftUI
import UIKit

enum PosterURLCache {
    static func configure() {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "aslPosterURLCache"
        )
    }
}

struct PosterImageView: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    @ObservedObject private var loader = PosterImageLoader.shared

    @State private var loadStarted: Date?

    var body: some View {
        let _ = store.mediaCacheRevision
        let _ = loader.revision

        posterContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear { beginRemoteLoadIfNeeded() }
            .onChange(of: store.mediaCacheRevision) { _, _ in
                if store.isPosterReady(for: wordId), let started = loadStarted {
                    store.recordDictionaryPosterReady(wordId: wordId, started: started)
                    loadStarted = nil
                }
            }
            .onChange(of: loader.revision) { _, _ in
                guard let url = store.posterDisplayURL(for: wordId),
                      loader.image(for: wordId, url: url) != nil,
                      let started = loadStarted else { return }
                store.recordDictionaryPosterReady(wordId: wordId, started: started)
                loadStarted = nil
            }
    }

    @ViewBuilder
    private var posterContent: some View {
        if ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) {
            SignFilmPlaceholder(
                title: ASLPendingFilmCatalog.title(for: wordId, store: store),
                height: nil,
                style: .thumbnail
            )
        } else if store.isDictionaryFilmed(wordId: wordId) {
            filmedPosterContent
        } else {
            posterSkeleton
        }
    }

    @ViewBuilder
    private var filmedPosterContent: some View {
        if let bundledURL = BundledSignMedia.posterURL(for: wordId),
           let image = UIImage(contentsOfFile: bundledURL.path) {
            posterImage(image)
        } else if let localURL = store.localPosterURL(for: wordId),
                  let image = UIImage(contentsOfFile: localURL.path) {
            posterImage(image)
        } else if let remoteURL = store.posterDisplayURL(for: wordId),
                  let image = loader.image(for: wordId, url: remoteURL) {
            posterImage(image)
        } else {
            posterSkeleton
        }
    }

    private func posterImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }

    private func beginRemoteLoadIfNeeded() {
        guard store.isDictionaryFilmed(wordId: wordId) else { return }
        guard BundledSignMedia.posterURL(for: wordId) == nil else { return }
        guard !store.isPosterReady(for: wordId) else { return }
        guard let remoteURL = store.posterDisplayURL(for: wordId) else { return }
        guard loader.image(for: wordId, url: remoteURL) == nil else { return }
        guard !loader.isLoading(wordId: wordId, url: remoteURL) else { return }
        if loadStarted == nil {
            loadStarted = Date()
        }
        loader.load(wordId: wordId, url: remoteURL)
    }

    private var posterSkeleton: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.92, blue: 0.96),
                        Color(red: 0.86, green: 0.94, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
