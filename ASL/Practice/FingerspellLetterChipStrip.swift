//
//  FingerspellLetterChipStrip.swift
//  ASL
//

import AVFoundation
import SwiftUI

enum FingerspellChipState: Equatable {
    case upcoming
    case active
    case completed
    case doubleLetter
}

struct FingerspellLetterChipStrip: View {
    let letterWordIds: [String]
    var activeIndex: Int?
    var completedThrough: Int?
    var doubleLetterIndices: Set<Int> = []
    var onTapIndex: ((Int) -> Void)?

    private let palette: Color = PracticeTheme.accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(letterWordIds.enumerated()), id: \.offset) { index, wordId in
                    chip(index: index, wordId: wordId)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(index: Int, wordId: String) -> some View {
        let label = FingerspellLetterMapper.displayLabel(for: wordId)
        let state = chipState(for: index)
        return Button {
            Haptics.tap()
            onTapIndex?(index)
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.asl(18, weight: .semibold, design: .ui))
                    .foregroundStyle(foreground(for: state))
                if state == .doubleLetter {
                    Text("again")
                        .font(.aslReading(10, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                }
            }
            .frame(minWidth: 40, minHeight: 44)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background(for: state))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(border(for: state), lineWidth: state == .active ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTapIndex == nil)
        .accessibilityLabel(accessibilityLabel(index: index, label: label, state: state))
    }

    private func chipState(for index: Int) -> FingerspellChipState {
        if let activeIndex, index == activeIndex { return .active }
        if doubleLetterIndices.contains(index) { return .doubleLetter }
        if let completedThrough, index <= completedThrough { return .completed }
        return .upcoming
    }

    private func background(for state: FingerspellChipState) -> Color {
        switch state {
        case .upcoming: return Brand.homeBackground
        case .active: return palette.opacity(0.18)
        case .completed: return palette.opacity(0.12)
        case .doubleLetter: return palette.opacity(0.14)
        }
    }

    private func border(for state: FingerspellChipState) -> Color {
        switch state {
        case .upcoming: return Brand.divider.opacity(0.8)
        case .active: return palette
        case .completed: return palette.opacity(0.45)
        case .doubleLetter: return palette.opacity(0.55)
        }
    }

    private func foreground(for state: FingerspellChipState) -> Color {
        switch state {
        case .upcoming: return Brand.secondaryLabel
        default: return Brand.textPrimary
        }
    }

    private func accessibilityLabel(index: Int, label: String, state: FingerspellChipState) -> String {
        let position = "Letter \(label), \(index + 1) of \(letterWordIds.count)"
        switch state {
        case .active: return "\(position), active"
        case .completed: return "\(position), completed"
        case .doubleLetter: return "\(position), repeat letter"
        case .upcoming: return position
        }
    }
}

struct FingerspellSequenceVideoPlayer: View {
    @ObservedObject var controller: FingerspellSequenceController
    var cornerRadius: CGFloat = 16
    var height: CGFloat = 220
    var showsSlowMotionControl: Bool = false

    var body: some View {
        VideoLayer(
            player: controller.player,
            videoGravity: .resizeAspectFill,
            placeholderColor: Brand.homeBackground
        )
        .frame(height: height)
        .background(Brand.homeBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showsSlowMotionControl {
                FingerspellVideoControlsOverlay(controller: controller)
            }
        }
    }
}

/// Shared turtle (slow-mo) control for fingerspell letter videos — matches `SignVideoControlsOverlay`.
struct FingerspellVideoControlsOverlay: View {
    @ObservedObject var controller: FingerspellSequenceController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                controlButton(systemName: "tortoise.fill", isActive: controller.isSlowMotionEnabled) {
                    controller.toggleSlowMotion()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private func controlButton(
        systemName: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.asl(15, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Brand.textPrimary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(isActive ? Color.lessonGreen : Color.white)
                )
                .overlay(
                    Circle().strokeBorder(Brand.divider.opacity(0.6), lineWidth: 1)
                )
                .elevation(.raisedControl(tint: Brand.ink, isPressed: false))
                .animation(.easeOut(duration: 0.18), value: isActive)
        }
        .buttonStyle(.plain)
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
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.backgroundColor = UIColor(placeholderColor)
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
}
