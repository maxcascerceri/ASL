//
//  YourTurnStepView.swift
//  ASL
//
//  "Your Turn" active-practice step: watch the reference sign, record on a
//  full-screen front camera page with a PiP reference, then review before Done.
//  Not graded; the lesson tray advances the flow.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

// MARK: - Phase

enum YourTurnPhase: Equatable {
    case watch
    case recording
    case review
}

// MARK: - Camera controller

/// Opted out of the project's default `MainActor` isolation so AVFoundation
/// session/recording callbacks (delivered on private queues) can touch it
/// directly. All `@Published` mutations hop back to the main thread.
nonisolated final class YourTurnCameraController: NSObject, ObservableObject, @unchecked Sendable {
    enum Phase: Equatable {
        case idle
        case recording
        case recorded
    }

    @Published private(set) var phase: Phase = .idle
    @Published var permissionDenied = false
    @Published private(set) var recordedURL: URL?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "asl.yourturn.session")
    private var isConfigured = false

    func configureIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in self?.setupSessionIfNeeded() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async { self.setupSessionIfNeeded() }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    private func setupSessionIfNeeded() {
        guard !isConfigured else {
            startRunning()
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video),
               connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
        session.commitConfiguration()
        isConfigured = true
        startRunning()
    }

    private func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleRecording() {
        let output = movieOutput
        if output.isRecording {
            sessionQueue.async { output.stopRecording() }
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yourturn-\(UUID().uuidString).mov")
        phase = .recording
        sessionQueue.async { [weak self] in
            guard let self else { return }
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    func reset() {
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        phase = .idle
    }
}

extension YourTurnCameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if error != nil {
                self.phase = .idle
                return
            }
            self.recordedURL = outputFileURL
            self.phase = .recorded
        }
    }
}

// MARK: - Camera preview

private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        applyMirroredFrontCameraPreview(to: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        applyMirroredFrontCameraPreview(to: uiView.videoPreviewLayer)
    }

    private func applyMirroredFrontCameraPreview(to layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Step router

struct YourTurnStepView: View {
    let lessonId: String
    let referenceWordId: String
    let title: String
    let prompt: String
    @Binding var phase: YourTurnPhase
    @ObservedObject var store: ASLDataStore
    let palette: Color
    let paletteShadow: Color

    @StateObject private var camera = YourTurnCameraController()
    @StateObject private var referenceController = LessonPlayerController()
    @StateObject private var pipController = LessonPlayerController()
    @StateObject private var playbackController = LessonPlayerController()
    @State private var attachedWordId: String?
    @State private var pipAttachedWordId: String?

    var body: some View {
        Group {
            switch phase {
            case .watch:
                YourTurnWatchView(
                    title: title,
                    subtitle: ASLLessonPromptFraming.yourTurnWatchSubtitle(
                        lessonId: lessonId,
                        wordId: referenceWordId,
                        authoredPrompt: prompt
                    ),
                    wordLabel: ASLWordDisplay.title(for: referenceWordId),
                    referenceWordId: referenceWordId,
                    referenceController: referenceController,
                    store: store
                )
            case .review:
                YourTurnReviewView(
                    referenceWordId: referenceWordId,
                    reviewPrompt: ASLLessonPromptFraming.yourTurnReviewPrompt(
                        lessonId: lessonId,
                        wordId: referenceWordId
                    ),
                    referenceController: referenceController,
                    playbackController: playbackController,
                    recordedURL: camera.recordedURL,
                    store: store,
                    palette: palette,
                    onReRecord: beginReRecord
                )
            case .recording:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { attachMainReferenceIfNeeded() }
        .onChange(of: store.mediaCacheRevision) { _, _ in attachMainReferenceIfNeeded() }
        .onChange(of: store.videosByWordId.count) { _, _ in attachMainReferenceIfNeeded() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .recording {
                attachPipReferenceIfNeeded()
            }
        }
        .onChange(of: camera.recordedURL) { _, url in
            guard let url, phase == .recording else { return }
            playbackController.load(url, wordId: nil)
            playbackController.replay()
            phase = .review
        }
        .fullScreenCover(isPresented: recordingPresented) {
            YourTurnRecordingView(
                referenceWordId: referenceWordId,
                camera: camera,
                pipController: pipController,
                store: store,
                palette: palette,
                onClose: { phase = .watch }
            )
        }
    }

    private var recordingPresented: Binding<Bool> {
        Binding(
            get: { phase == .recording },
            set: { isPresented in
                if !isPresented, phase == .recording {
                    phase = .watch
                }
            }
        )
    }

    private func beginReRecord() {
        Haptics.tap()
        camera.reset()
        phase = .recording
    }

    private func attachMainReferenceIfNeeded() {
        guard !ASLPendingFilmCatalog.shouldShowPlaceholder(for: referenceWordId, store: store) else { return }
        attachedWordId = referenceWordId
        Task {
            await store.ensureVideoAttached(to: referenceController, wordId: referenceWordId)
            guard attachedWordId == referenceWordId else { return }
            referenceController.playAtNormalSpeed()
            referenceController.replay()
        }
    }

    private func attachPipReferenceIfNeeded() {
        guard !ASLPendingFilmCatalog.shouldShowPlaceholder(for: referenceWordId, store: store) else { return }
        pipAttachedWordId = referenceWordId
        Task {
            await store.ensureVideoAttached(to: pipController, wordId: referenceWordId)
            guard pipAttachedWordId == referenceWordId else { return }
            pipController.playAtNormalSpeed()
            pipController.replay()
        }
    }
}

// MARK: - Watch page

private struct YourTurnWatchView: View {
    let title: String
    let subtitle: String
    let wordLabel: String
    let referenceWordId: String
    @ObservedObject var referenceController: LessonPlayerController
    @ObservedObject var store: ASLDataStore

    var body: some View {
        LessonStepStack {
            LessonPromptLabel(text: title.isEmpty ? "Your Turn" : title)
        } media: {
            LessonVideoStage(
                controller: referenceController,
                wordId: referenceWordId,
                store: store,
                height: LessonQuestionLayout.videoHeight,
                showsControls: true
            )
        } controls: {
            VStack(spacing: 8) {
                Text(subtitle)
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                Text(wordLabel)
                    .font(LessonQuestionLayout.teachWordFont)
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
    }
}

// MARK: - Recording cover

struct YourTurnRecordingView: View {
    let referenceWordId: String
    @ObservedObject var camera: YourTurnCameraController
    @ObservedObject var pipController: LessonPlayerController
    @ObservedObject var store: ASLDataStore
    let palette: Color
    let onClose: () -> Void
    var sequenceController: FingerspellSequenceController?
    var sequenceWordIds: [String] = []

    @State private var pipAttachedWordId: String?

    private let pipWidth: CGFloat = 110
    private let pipHeight: CGFloat = 150

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permissionDenied {
                permissionDeniedContent
            } else {
                CameraPreviewLayerView(session: camera.session)
                    .ignoresSafeArea()

                VStack {
                    HStack(alignment: .top, spacing: 12) {
                        closeButton
                        Spacer(minLength: 0)
                        pipReference
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer(minLength: 0)

                    if camera.phase == .recording {
                        Text("Recording — tap stop when you're done.")
                            .font(LessonQuestionLayout.subtitleFont)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }

                    recordButton
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            camera.configureIfNeeded()
            attachPipIfNeeded()
        }
        .onDisappear { camera.stop() }
        .onChange(of: store.mediaCacheRevision) { _, _ in attachPipIfNeeded() }
        .onChange(of: store.videosByWordId.count) { _, _ in attachPipIfNeeded() }
    }

    private var closeButton: some View {
        Button {
            Haptics.tap()
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.asl(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
    }

    private var pipReference: some View {
        VStack(spacing: 4) {
            Text("EXAMPLE")
                .font(.aslReading(11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white)
            Group {
                if let sequenceController {
                    FingerspellSequenceVideoPlayer(
                        controller: sequenceController,
                        cornerRadius: 12,
                        height: pipHeight - 18
                    )
                } else {
                    LessonVideoPlayer(
                        controller: pipController,
                        cornerRadius: 12,
                        videoGravity: .resizeAspectFill,
                        placeholderColor: .black
                    )
                }
            }
            .frame(width: pipWidth, height: pipHeight - 18)
        }
        .scaleEffect(1)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: camera.phase)
    }

    private var recordButton: some View {
        Button {
            Haptics.tap()
            camera.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 68, height: 68)
                    .elevation(.raisedControl(tint: Brand.ink, isPressed: false))
                RoundedRectangle(cornerRadius: camera.phase == .recording ? 6 : 28, style: .continuous)
                    .fill(Color.lessonCoralButton)
                    .frame(
                        width: camera.phase == .recording ? 28 : 56,
                        height: camera.phase == .recording ? 28 : 56
                    )
                    .animation(.easeInOut(duration: 0.2), value: camera.phase)
            }
        }
        .buttonStyle(.plain)
        .disabled(camera.permissionDenied)
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.asl(32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera access is off. Enable it in Settings to record yourself.")
                .font(LessonQuestionLayout.subtitleFont)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.asl(14, weight: .medium))
            .foregroundStyle(palette)
            Button("Close") {
                Haptics.tap()
                onClose()
            }
            .font(.asl(14, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.top, 8)
        }
    }

    private func attachPipIfNeeded() {
        if let sequenceController, !sequenceWordIds.isEmpty {
            Task {
                await sequenceController.playSequence(
                    wordIds: sequenceWordIds,
                    store: store,
                    loop: true
                )
            }
            return
        }
        guard !ASLPendingFilmCatalog.shouldShowPlaceholder(for: referenceWordId, store: store) else { return }
        pipAttachedWordId = referenceWordId
        Task {
            await store.ensureVideoAttached(to: pipController, wordId: referenceWordId)
            guard pipAttachedWordId == referenceWordId else { return }
            pipController.playAtNormalSpeed()
            pipController.replay()
        }
    }
}

// MARK: - Review page

struct YourTurnReviewView: View {
    let referenceWordId: String
    let reviewPrompt: ASLLessonPromptFraming.YourTurnReviewPrompt
    @ObservedObject var referenceController: LessonPlayerController
    @ObservedObject var playbackController: LessonPlayerController
    let recordedURL: URL?
    @ObservedObject var store: ASLDataStore
    let palette: Color
    let onReRecord: () -> Void
    var sequenceController: FingerspellSequenceController?
    var sequenceWordIds: [String] = []

    private let pipWidth: CGFloat = 108
    private let pipVideoHeight: CGFloat = 136

    var body: some View {
        LessonStepStack(spacing: 14) {
            LessonPromptLabel(text: "Your Turn")
        } media: {
            ZStack(alignment: .topTrailing) {
                recordingStage
                pipReference
                    .padding(12)
            }
        } controls: {
            VStack(spacing: 4) {
                Text(reviewPrompt.headline)
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                YourTurnReviewSubline(
                    subline: reviewPrompt.subline,
                    palette: palette,
                    onReRecord: onReRecord
                )
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, LessonQuestionLayout.horizontalPadding)
        .onAppear { attachReferenceIfNeeded() }
    }

    private func attachReferenceIfNeeded() {
        if let sequenceController, !sequenceWordIds.isEmpty {
            Task {
                await sequenceController.playSequence(
                    wordIds: sequenceWordIds,
                    store: store,
                    loop: true
                )
            }
        }
    }

    private var recordingStage: some View {
        Group {
            if recordedURL != nil {
                LessonVideoPlayer(
                    controller: playbackController,
                    cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                    videoGravity: .resizeAspectFill,
                    placeholderColor: Brand.homeBackground
                )
                .padding(SignVideoCardMetrics.innerPadding)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: LessonQuestionLayout.yourTurnReviewVideoHeight)
        .background(Brand.homeBackground)
        .clipShape(RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SignVideoCardMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
        }
        .elevation(.insetField)
    }

    private var pipReference: some View {
        VStack(spacing: 4) {
            Text("EXAMPLE")
                .font(.aslReading(11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white)
            Group {
                if let sequenceController {
                    FingerspellSequenceVideoPlayer(
                        controller: sequenceController,
                        cornerRadius: 12,
                        height: pipVideoHeight
                    )
                } else {
                    LessonVideoPlayer(
                        controller: referenceController,
                        cornerRadius: 12,
                        videoGravity: .resizeAspectFill,
                        placeholderColor: Brand.homeBackground
                    )
                }
            }
            .frame(width: pipWidth, height: pipVideoHeight)
        }
    }
}

private struct YourTurnReviewSubline: View {
    let subline: String
    let palette: Color
    let onReRecord: () -> Void

    private static let actionLabel = "Re-record"

    var body: some View {
        Group {
            if let range = subline.range(of: Self.actionLabel) {
                let prefix = String(subline[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let suffix = String(subline[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                VStack(spacing: 2) {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(LessonQuestionLayout.subtitleFont)
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }

                    Button(Self.actionLabel) {
                        Haptics.tap()
                        onReRecord()
                    }
                    .buttonStyle(.plain)
                    .font(LessonQuestionLayout.subtitleFont.weight(.semibold))
                    .foregroundStyle(palette)

                    if !suffix.isEmpty {
                        Text(suffix)
                            .font(LessonQuestionLayout.subtitleFont)
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(subline)
                    .font(LessonQuestionLayout.subtitleFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
