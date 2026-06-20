//
//  LessonVideoPlayer.swift
//  ASL
//
//  AVPlayer wrapper used inside every gameplay view. Hides the iOS system
//  player chrome, loops by default, and exposes the slow-mo replay knob each
//  stone needs after a wrong answer.
//

import AVFoundation
import AVKit
import Combine
import SwiftUI

@MainActor
final class LessonPlayerController: ObservableObject {
    /// Rate the looping video plays at when the turtle (slow-mo) toggle is on.
    static let slowMotionRate: Float = 0.5

    @Published private(set) var url: URL?
    @Published private(set) var loadedWordId: String?
    @Published private(set) var isPlaybackReady = false
    @Published private(set) var playbackFailed = false
    /// Drives the green turtle toggle in `SignVideoControlsOverlay`. When true
    /// the video loops continuously at `slowMotionRate` until toggled off.
    @Published private(set) var isSlowMotionEnabled = false
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var rateObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var observedItemAddress: ObjectIdentifier?
    /// Lesson stages expect the sign clip to keep looping until explicitly paused.
    private var expectsContinuousPlayback = false
    /// Active `LessonVideoPlayer` surfaces sharing this controller.
    private var displayCount = 0

    var isDisplaying: Bool { displayCount > 0 }

    init() {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        rateObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.maintainContinuousPlayback()
            }
        }
    }

    deinit {
        if let token = rateObserverToken {
            player.removeTimeObserver(token)
        }
    }

    private var normalRate: Float { isSlowMotionEnabled ? Self.slowMotionRate : 1.0 }

    private func enforceSlowMotionRateIfNeeded() {
        guard isSlowMotionEnabled else { return }
        if player.timeControlStatus == .playing, player.rate != Self.slowMotionRate {
            player.rate = Self.slowMotionRate
        }
    }

    private func maintainContinuousPlayback() {
        enforceSlowMotionRateIfNeeded()
        guard expectsContinuousPlayback, isPlaybackReady else { return }
        guard player.timeControlStatus == .paused else { return }
        player.play()
        player.rate = normalRate
    }

    func load(_ url: URL, wordId: String? = nil) {
        if url == self.url, wordId == loadedWordId, isPlaybackReady { return }
        resetPlaybackState()
        self.url = url
        if loadedWordId != wordId { isSlowMotionEnabled = false }
        loadedWordId = wordId
        player.automaticallyWaitsToMinimizeStalling = !url.isFileURL

        let template = AVPlayerItem(url: url)
        attachLooper(templateItem: template)
    }

    /// Bundled / disk-backed clips — preload asset, then queue via AVPlayerLooper.
    func loadLocal(url: URL, wordId: String? = nil) async {
        if url == self.url, wordId == loadedWordId, isPlaybackReady { return }
        resetPlaybackState()
        self.url = url
        if loadedWordId != wordId { isSlowMotionEnabled = false }
        loadedWordId = wordId
        player.automaticallyWaitsToMinimizeStalling = false

        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                playbackFailed = true
                logLoadFailure(wordId: wordId, url: url, reason: "asset not playable")
                return
            }
            _ = try await asset.load(.tracks)
        } catch {
            playbackFailed = true
            logLoadFailure(wordId: wordId, url: url, reason: error.localizedDescription)
            return
        }

        let template = AVPlayerItem(asset: asset)
        attachLooper(templateItem: template)
        bindCurrentItemObservation()
        await awaitPlaybackReady(timeout: 2)
        if !isPlaybackReady, !playbackFailed {
            logLoadFailure(
                wordId: wordId,
                url: url,
                reason: "timeout status=\(player.currentItem?.status.rawValue ?? -1)"
            )
        }
    }

    func load(_ item: AVPlayerItem, wordId: String? = nil) {
        guard let asset = item.asset as? AVURLAsset else { return }
        if asset.url == self.url, wordId == loadedWordId, isPlaybackReady { return }
        resetPlaybackState()
        if loadedWordId != wordId { isSlowMotionEnabled = false }
        self.url = asset.url
        loadedWordId = wordId
        player.automaticallyWaitsToMinimizeStalling = !asset.url.isFileURL

        let template = item.copy() as! AVPlayerItem
        attachLooper(templateItem: template)
        bindCurrentItemObservation()
    }

    func awaitPlaybackReady(timeout: TimeInterval = 20) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPlaybackReady || playbackFailed { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func setSlowMotion(_ enabled: Bool) {
        guard enabled != isSlowMotionEnabled else { return }
        isSlowMotionEnabled = enabled
        if isPlaybackReady {
            player.rate = normalRate
        }
    }

    func toggleSlowMotion() {
        setSlowMotion(!isSlowMotionEnabled)
    }

    func playAtNormalSpeed() {
        guard isPlaybackReady else { return }
        expectsContinuousPlayback = true
        player.rate = normalRate
        if player.timeControlStatus != .playing {
            player.play()
            player.rate = normalRate
        }
    }

    /// Call from `LessonVideoPlayer.onAppear` so shared controllers survive step transitions.
    func beginDisplaying() {
        displayCount += 1
        if isPlaybackReady {
            playAtNormalSpeed()
        }
    }

    /// Call from `LessonVideoPlayer.onDisappear`; pauses only when no surface is visible.
    func endDisplaying() {
        displayCount = max(0, displayCount - 1)
        if displayCount == 0 {
            pause()
        }
    }

    func playSlowMotion() {
        guard isPlaybackReady else { return }
        expectsContinuousPlayback = true
        if looper != nil {
            player.rate = Self.slowMotionRate
            if player.timeControlStatus != .playing {
                player.play()
                player.rate = Self.slowMotionRate
            }
        } else {
            player.seek(to: .zero) { [weak self] _ in
                guard let self else { return }
                self.player.rate = Self.slowMotionRate
            }
        }
    }

    func replay() {
        guard isPlaybackReady else { return }
        expectsContinuousPlayback = true
        if looper != nil {
            // Seeking on AVQueuePlayer breaks AVPlayerLooper; resume rate instead.
            player.rate = normalRate
            if player.timeControlStatus != .playing {
                player.play()
                player.rate = normalRate
            }
        } else {
            player.seek(to: .zero)
            player.rate = normalRate
        }
    }

    /// Restarts or continues looping without re-seeking when the clip is already loaded.
    func resumeLooping() {
        playAtNormalSpeed()
    }

    func pause() {
        expectsContinuousPlayback = false
        player.pause()
    }

    func resume() {
        guard isPlaybackReady else { return }
        expectsContinuousPlayback = true
        player.rate = normalRate
        if player.timeControlStatus != .playing {
            player.play()
            player.rate = normalRate
        }
    }

    func prepareForWord(_ wordId: String) {
        if loadedWordId != wordId, !isPlaybackReady {
            resetPlaybackState()
            loadedWordId = nil
        }
    }

    /// Clears the current clip so a prior sign cannot keep looping on the stage.
    func detach() {
        expectsContinuousPlayback = false
        resetPlaybackState()
        loadedWordId = nil
        url = nil
        player.pause()
    }

    private func resetPlaybackState() {
        isPlaybackReady = false
        playbackFailed = false
        statusObservation?.invalidate()
        statusObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        observedItemAddress = nil
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }

    private func attachLooper(templateItem: AVPlayerItem) {
        looper = AVPlayerLooper(player: player, templateItem: templateItem)
        bindCurrentItemObservation()
    }

    private func bindCurrentItemObservation() {
        currentItemObservation?.invalidate()
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                self.observeCurrentItemStatus(player.currentItem)
            }
        }
    }

    private func observeCurrentItemStatus(_ item: AVPlayerItem?) {
        guard let item else { return }
        let address = ObjectIdentifier(item)
        if observedItemAddress == address { return }
        observedItemAddress = address

        statusObservation?.invalidate()
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.player.currentItem === observed else { return }
                switch observed.status {
                case .readyToPlay:
                    self.isPlaybackReady = true
                    self.playbackFailed = false
                    guard self.isDisplaying else { return }
                    self.expectsContinuousPlayback = true
                    self.player.rate = self.normalRate
                    if self.player.timeControlStatus != .playing {
                        self.player.play()
                        self.player.rate = self.normalRate
                    }
                case .failed:
                    self.isPlaybackReady = false
                    self.playbackFailed = true
                    #if DEBUG
                    if let asset = observed.asset as? AVURLAsset {
                        self.logLoadFailure(
                            wordId: self.loadedWordId,
                            url: asset.url,
                            reason: observed.error?.localizedDescription ?? "unknown"
                        )
                    } else {
                        print(
                            "[LessonPlayerController] playback failed \(self.loadedWordId ?? "?"): "
                                + "\(observed.error?.localizedDescription ?? "unknown")"
                        )
                    }
                    #endif
                default:
                    break
                }
            }
        }
    }

    private func logLoadFailure(wordId: String?, url: URL, reason: String) {
        #if DEBUG
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? -1
        print(
            "[LessonPlayerController] playback failed \(wordId ?? "?") "
                + "file=\(url.lastPathComponent) bytes=\(size) reason=\(reason)"
        )
        #endif
    }
}

struct LessonVideoPlayer: View {
    @ObservedObject var controller: LessonPlayerController
    var cornerRadius: CGFloat = 16
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var placeholderColor: Color = Brand.homeBackground

    var body: some View {
        VideoLayer(
            player: controller.player,
            videoGravity: videoGravity,
            placeholderColor: placeholderColor
        )
        .background(placeholderColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            controller.beginDisplaying()
        }
        .onChange(of: controller.isPlaybackReady) { _, ready in
            if ready, controller.isDisplaying {
                controller.playAtNormalSpeed()
            }
        }
        .onDisappear {
            controller.endDisplaying()
        }
    }
}

private struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let placeholderColor: Color

    final class PlayerHostView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        view.playerLayer.videoGravity = videoGravity
        view.playerLayer.player = player
        view.backgroundColor = UIColor(placeholderColor)
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        uiView.clipsToBounds = true
        uiView.layer.masksToBounds = true
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        if uiView.playerLayer.videoGravity != videoGravity {
            uiView.playerLayer.videoGravity = videoGravity
        }
        uiView.backgroundColor = UIColor(placeholderColor)
    }
}
