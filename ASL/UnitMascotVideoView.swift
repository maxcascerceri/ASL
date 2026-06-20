import AVFoundation
import SwiftUI

/// Bundled mascot video that plays once per app session, then swaps to a static image.
struct UnitMascotVideoView: View {
    let resourceName: String
    let fallbackImageName: String
    let size: CGFloat
    let introSlot: UnitMascot.MascotIntroSlot
    var usesOriginalRendering = false

    @State private var videoURL: URL?
    @State private var showVideoPlayer = false
    @State private var hideStaticImage = false
    @State private var hasNonZeroLayout = false

    var body: some View {
        ZStack {
            fallbackImage
                .opacity(hideStaticImage ? 0 : 1)

            if showVideoPlayer, let videoURL {
                BundledMascotVideoView(
                    url: videoURL,
                    onPlaybackStarted: {
                        hideStaticImage = true
                    },
                    onPlaybackFailed: {
                        hideStaticImage = false
                        showVideoPlayer = false
                    },
                    onPlaybackEnded: {
                        UnitMascot.markIntroVideoPlayed(for: introSlot)
                        hideStaticImage = false
                        showVideoPlayer = false
                    }
                )
                .frame(width: size, height: size)
            }
        }
        .transaction { $0.disablesAnimations = true }
        .frame(width: size, height: size)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateLayoutReadiness(from: proxy.size) }
                    .onChange(of: proxy.size) { _, newSize in
                        updateLayoutReadiness(from: newSize)
                    }
            }
        }
        .onAppear(perform: refreshIntroPlaybackState)
        .onChange(of: hasNonZeroLayout) { _, isReady in
            guard isReady else { return }
            refreshIntroPlaybackState()
        }
    }

    private func updateLayoutReadiness(from size: CGSize) {
        let isReady = size.width > 1 && size.height > 1
        guard isReady != hasNonZeroLayout else { return }
        hasNonZeroLayout = isReady
    }

    private func refreshIntroPlaybackState() {
        guard hasNonZeroLayout else { return }
        guard UnitMascot.shouldPlayIntroVideo(for: introSlot) else {
            showVideoPlayer = false
            return
        }

        let resolvedURL = UnitMascot.bundleVideoURL(for: resourceName)
        videoURL = resolvedURL
        showVideoPlayer = resolvedURL != nil
    }

    @ViewBuilder
    private var fallbackImage: some View {
        if usesOriginalRendering {
            Image(fallbackImageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            Image(fallbackImageName)
                .resizable()
                .scaledToFit()
        }
    }
}

private struct BundledMascotVideoView: UIViewRepresentable {
    let url: URL
    let onPlaybackStarted: () -> Void
    let onPlaybackFailed: () -> Void
    let onPlaybackEnded: () -> Void

    func makeUIView(context: Context) -> MascotPlayerUIView {
        let view = MascotPlayerUIView()
        view.onPlaybackStarted = onPlaybackStarted
        view.onPlaybackFailed = onPlaybackFailed
        view.onPlaybackEnded = onPlaybackEnded
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: MascotPlayerUIView, context: Context) {
        uiView.onPlaybackStarted = onPlaybackStarted
        uiView.onPlaybackFailed = onPlaybackFailed
        uiView.onPlaybackEnded = onPlaybackEnded
        uiView.configure(url: url)
    }

    static func dismantleUIView(_ uiView: MascotPlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }
}

private final class MascotPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private static let playbackRate: Float = 1.2

    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFailed: (() -> Void)?
    var onPlaybackEnded: (() -> Void)?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var configuredURL: URL?

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func configure(url: URL) {
        guard configuredURL != url else { return }
        tearDown()
        configuredURL = url

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        playerLayer.videoGravity = .resizeAspect
        playerLayer.player = player
        playerLayer.backgroundColor = UIColor.clear.cgColor
        self.player = player

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch observed.status {
                case .readyToPlay:
                    self.onPlaybackStarted?()
                    player.play()
                    player.rate = Self.playbackRate
                case .failed:
                    self.onPlaybackStarted = nil
                    self.onPlaybackFailed?()
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.playerLayer.player = nil
            self.player?.pause()
            self.onPlaybackEnded?()
        }
    }

    func tearDown() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
        configuredURL = nil
    }

    deinit {
        tearDown()
    }
}
