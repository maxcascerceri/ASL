//
//  PosterImageLoader.swift
//  ASL
//
//  Coalesced grid poster HTTP loads with display-size decode.
//

import Combine
import Foundation
import ImageIO
import UIKit

@MainActor
final class PosterImageLoader: ObservableObject {
    static let shared = PosterImageLoader()

    @Published private(set) var revision = 0

    private var imagesByCacheKey: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    /// ~192pt grid cell width at device scale.
    private var maxPixelSize: CGFloat {
        192 * UIScreen.main.scale
    }

    static func cacheKey(wordId: String, url: URL) -> String {
        "\(wordId)|\(url.lastPathComponent)"
    }

    func image(for wordId: String, url: URL) -> UIImage? {
        imagesByCacheKey[Self.cacheKey(wordId: wordId, url: url)]
    }

    func isLoading(wordId: String, url: URL) -> Bool {
        inFlight[Self.cacheKey(wordId: wordId, url: url)] != nil
    }

    func load(wordId: String, url: URL) {
        let key = Self.cacheKey(wordId: wordId, url: url)
        if imagesByCacheKey[key] != nil { return }
        if inFlight[key] != nil { return }

        inFlight[key] = Task { @MainActor in
            let image = await Self.fetchAndDecode(url: url, maxPixelSize: maxPixelSize)
            if let image {
                imagesByCacheKey[key] = image
                revision += 1
            }
            inFlight.removeValue(forKey: key)
            return image
        }
    }

    func clear(wordId: String, url: URL) {
        let key = Self.cacheKey(wordId: wordId, url: url)
        imagesByCacheKey.removeValue(forKey: key)
        inFlight[key]?.cancel()
        inFlight.removeValue(forKey: key)
    }

    private static func fetchAndDecode(url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return downsampledImage(data: data, maxPixelSize: maxPixelSize)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return downsampledImage(data: data, maxPixelSize: maxPixelSize)
        } catch {
            #if DEBUG
            print("[PosterImageLoader] failed \(url.lastPathComponent): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private static func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
