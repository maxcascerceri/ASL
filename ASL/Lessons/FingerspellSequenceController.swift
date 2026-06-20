//
//  FingerspellSequenceController.swift
//  ASL
//

import AVFoundation
import Combine
import Foundation

enum FingerspellPlaybackMode: Equatable {
    case idle
    case singleLetterLoop(wordId: String)
    case playOnce(wordId: String)
    case sequence(wordIds: [String], pauseMs: Int)
}

@MainActor
final class FingerspellSequenceController: ObservableObject {
    static let slowMotionRate: Float = 0.5

    @Published private(set) var mode: FingerspellPlaybackMode = .idle
    @Published private(set) var currentLetterIndex: Int = 0
    @Published private(set) var isPlaybackReady = false
    @Published private(set) var playbackFailed = false
    @Published private(set) var isSlowMotionEnabled = false
    @Published private(set) var isPlayingSequence = false
    @Published private(set) var isSequencePreloaded = false

    let player = AVQueuePlayer()
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var sequenceEndObserver: NSObjectProtocol?
    private var sequenceWordIds: [String] = []
    private var sequencePauseMs = 0
    private var loopObserver: NSObjectProtocol?
    private var rateObserverToken: Any?
    private var expectsContinuousLoop = false
    private var preparedItems: [AVPlayerItem] = []
    private var preparedWordIds: [String] = []
    private var preloadTask: Task<Void, Never>?
    private var shouldLoopSequence = false

    init() {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        rateObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.maintainContinuousLoop()
            }
        }
    }

    deinit {
        if let rateObserverToken {
            player.removeTimeObserver(rateObserverToken)
        }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
        if let sequenceEndObserver { NotificationCenter.default.removeObserver(sequenceEndObserver) }
    }

    /// Warms every letter clip for a name so flow playback can queue them with no load gap.
    func preloadSequence(wordIds: [String], store: ASLDataStore) async {
        if preparedWordIds == wordIds,
           preparedItems.count == wordIds.count,
           preparedItems.allSatisfy({ $0.status == .readyToPlay }) {
            isSequencePreloaded = true
            return
        }

        preloadTask?.cancel()
        let task = Task {
            await loadPreparedItems(wordIds: wordIds, store: store)
        }
        preloadTask = task
        await task.value
    }

    func loadLetter(wordId: String, store: ASLDataStore, loop: Bool) async {
        stop(clearPreparedSequence: false)
        guard let url = store.localMediaFileURL(for: wordId) else {
            playbackFailed = true
            return
        }
        mode = loop ? .singleLetterLoop(wordId: wordId) : .playOnce(wordId: wordId)
        await attachItem(url: url, wordId: wordId, loop: loop)
    }

    func playSequence(wordIds: [String], store: ASLDataStore, pauseMs: Int = 0, loop: Bool = false) async {
        stop(clearPreparedSequence: false)
        shouldLoopSequence = loop
        guard !wordIds.isEmpty else { return }

        if preparedWordIds != wordIds || preparedItems.count != wordIds.count {
            await preloadSequence(wordIds: wordIds, store: store)
        }
        guard preparedItems.count == wordIds.count else {
            playbackFailed = true
            return
        }

        sequenceWordIds = wordIds
        sequencePauseMs = pauseMs
        mode = .sequence(wordIds: wordIds, pauseMs: pauseMs)
        isPlayingSequence = true
        currentLetterIndex = 0
        playbackFailed = false

        await resetPreparedItemsToStart()
        await beginQueuedSequencePlayback()
    }

    func replaySequence(store: ASLDataStore) async {
        guard case .sequence(let wordIds, let pauseMs) = mode else { return }
        await playSequence(wordIds: wordIds, store: store, pauseMs: pauseMs, loop: shouldLoopSequence)
    }

    func setSlowMotion(_ enabled: Bool) {
        guard enabled != isSlowMotionEnabled else { return }
        isSlowMotionEnabled = enabled
        resumeLoopingIfNeeded()
    }

    func toggleSlowMotion() {
        setSlowMotion(!isSlowMotionEnabled)
    }

    func stop(clearPreparedSequence: Bool = true) {
        expectsContinuousLoop = false
        shouldLoopSequence = false
        isPlayingSequence = false
        player.pause()
        player.removeAllItems()
        tearDownItemObservers()
        tearDownSequenceObservers()
        isPlaybackReady = false
        playbackFailed = false
        mode = .idle
        if clearPreparedSequence {
            preloadTask?.cancel()
            preloadTask = nil
            preparedItems = []
            preparedWordIds = []
            isSequencePreloaded = false
        }
    }

    private func loadPreparedItems(wordIds: [String], store: ASLDataStore) async {
        preparedItems = []
        preparedWordIds = wordIds
        isSequencePreloaded = false

        guard !wordIds.isEmpty else { return }

        let indexedItems = await withTaskGroup(of: (Int, AVPlayerItem?).self) { group in
            for (index, wordId) in wordIds.enumerated() {
                group.addTask { @MainActor in
                    return await self.makePreparedItem(wordId: wordId, store: store, index: index)
                }
            }

            var results: [(Int, AVPlayerItem)] = []
            for await result in group {
                if let item = result.1 {
                    results.append((result.0, item))
                }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        guard !Task.isCancelled, indexedItems.count == wordIds.count else {
            playbackFailed = indexedItems.isEmpty
            return
        }

        preparedItems = indexedItems
        isSequencePreloaded = true
        playbackFailed = false
    }

    private func makePreparedItem(wordId: String, store: ASLDataStore, index: Int) async -> (Int, AVPlayerItem?) {
        guard let url = store.localMediaFileURL(for: wordId) else { return (index, nil) }
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else { return (index, nil) }
            _ = try await asset.load(.tracks)
        } catch {
            return (index, nil)
        }

        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .varispeed
        await waitUntilReady(item)
        guard item.status == .readyToPlay else { return (index, nil) }
        return (index, item)
    }

    private func waitUntilReady(_ item: AVPlayerItem) async {
        if item.status == .readyToPlay { return }
        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = item.observe(\.status, options: [.new]) { item, _ in
                switch item.status {
                case .readyToPlay, .failed:
                    observation?.invalidate()
                    continuation.resume()
                default:
                    break
                }
            }
        }
    }

    private func resetPreparedItemsToStart() async {
        for item in preparedItems {
            await item.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func beginQueuedSequencePlayback() async {
        expectsContinuousLoop = false
        player.actionAtItemEnd = .advance
        player.removeAllItems()

        var after: AVPlayerItem?
        for item in preparedItems {
            guard player.canInsert(item, after: after) else {
                playbackFailed = true
                isPlayingSequence = false
                return
            }
            player.insert(item, after: after)
            after = item
        }

        setupSequenceObservers()
        isPlaybackReady = true
        currentLetterIndex = 0
        player.play()
        player.rate = playbackRate
    }

    private func setupSequenceObservers() {
        tearDownSequenceObservers()

        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.syncCurrentLetterIndex(with: player.currentItem)
            }
        }

        if let lastItem = preparedItems.last {
            sequenceEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: lastItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.finishSequencePlayback()
                }
            }
        }
    }

    private func syncCurrentLetterIndex(with currentItem: AVPlayerItem?) {
        guard case .sequence = mode, isPlayingSequence else { return }
        guard let currentItem,
              let index = preparedItems.firstIndex(where: { $0 === currentItem }) else { return }
        currentLetterIndex = index
    }

    private func finishSequencePlayback() {
        guard isPlayingSequence else { return }
        isPlayingSequence = false
        currentLetterIndex = max(0, preparedItems.count - 1)
        if shouldLoopSequence {
            Task {
                await restartQueuedSequencePlayback()
            }
        }
    }

    private func restartQueuedSequencePlayback() async {
        guard shouldLoopSequence, case .sequence = mode, !preparedItems.isEmpty else { return }
        isPlayingSequence = true
        currentLetterIndex = 0
        await resetPreparedItemsToStart()
        await beginQueuedSequencePlayback()
    }

    private func tearDownSequenceObservers() {
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        if let sequenceEndObserver {
            NotificationCenter.default.removeObserver(sequenceEndObserver)
            self.sequenceEndObserver = nil
        }
    }

    private func tearDownItemObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }
    }

    private func attachItem(url: URL, wordId: String, loop: Bool) async {
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                playbackFailed = true
                return
            }
            _ = try await asset.load(.tracks)
        } catch {
            playbackFailed = true
            return
        }

        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .varispeed
        expectsContinuousLoop = loop
        player.actionAtItemEnd = loop ? .none : .pause
        player.removeAllItems()
        player.insert(item, after: nil)

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isPlaybackReady = true
                    self.playbackFailed = false
                    self.resumeLoopingIfNeeded()
                case .failed:
                    self.playbackFailed = true
                    self.isPlaybackReady = false
                default:
                    break
                }
            }
        }

        if loop {
            if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.restartLoop()
                }
            }
        } else {
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleSingleItemFinished()
                }
            }
        }
    }

    private func handleSingleItemFinished() async {
        switch mode {
        case .playOnce:
            break
        default:
            break
        }
    }

    private var playbackRate: Float {
        isSlowMotionEnabled ? Self.slowMotionRate : 1
    }

    private func resumeLoopingIfNeeded() {
        guard isPlaybackReady else { return }
        player.play()
        player.rate = playbackRate
    }

    private func restartLoop() {
        guard expectsContinuousLoop, isPlaybackReady else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.resumeLoopingIfNeeded()
            }
        }
    }

    private func maintainContinuousLoop() {
        guard expectsContinuousLoop, isPlaybackReady else { return }
        if isSlowMotionEnabled, player.timeControlStatus == .playing,
           player.rate != Self.slowMotionRate {
            player.rate = Self.slowMotionRate
        }
        guard player.timeControlStatus == .paused else { return }
        resumeLoopingIfNeeded()
    }
}
