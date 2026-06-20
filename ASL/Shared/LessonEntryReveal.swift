//
//  LessonEntryReveal.swift
//  ASL
//
//  Enter-only portal: home collapses inward (hole closes → full blue) → swap → hole opens revealing lesson.
//

import SwiftUI
import UIKit

// MARK: - Request

struct LessonEntryRevealRequest {
    let fillColor: Color
    /// Continue button center in global coordinate space.
    let origin: CGPoint
    let lesson: ASLLesson
    let unit: ASLUnit
}

// MARK: - Portal dismiss

private struct LessonPortalDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// When set, dismisses the lesson (instant pop; portal is enter-only).
    var lessonPortalDismiss: (() -> Void)? {
        get { self[LessonPortalDismissKey.self] }
        set { self[LessonPortalDismissKey.self] = newValue }
    }
}

// MARK: - Timing

enum LessonEntryRevealMetrics {
    /// Visible content shrinks to center; branded color fills in from the edges until full cover.
    static let collapseInDuration: TimeInterval = 0.54
    /// Portal opens back out from center, revealing the lesson underneath.
    static let expandOutDuration: TimeInterval = 0.72

    static var collapseInAnimation: Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: collapseInDuration)
    }

    static var expandOutAnimation: Animation {
        .timingCurve(0.8, 0, 0.6, 1, duration: expandOutDuration)
    }
}

enum PortalNavigation {
    @MainActor
    static func withoutStackAnimation(_ action: () -> Void) {
        UIView.setAnimationsEnabled(false)
        action()
        DispatchQueue.main.async {
            UIView.setAnimationsEnabled(true)
        }
    }
}

// MARK: - Coordinator

@Observable
final class LessonEntryRevealCoordinator {
    enum Phase: Equatable {
        case idle
        case pendingSheetDismiss
        case entering
        case presented
    }

    private(set) var phase: Phase = .idle
    private(set) var portalColor: Color = .clear
    private(set) var activeRequest: LessonEntryRevealRequest?
    private(set) var usesReduceMotion = false

    var onCommitNavigation: ((LessonEntryRevealRequest) -> Void)?
    var onDismissNavigation: (() -> Void)?

    var isPortalOverlayActive: Bool {
        phase == .entering
    }

    var suppressesTabBar: Bool {
        switch phase {
        case .pendingSheetDismiss, .entering, .presented:
            return true
        case .idle:
            return false
        }
    }

    func begin(request: LessonEntryRevealRequest, reduceMotion: Bool) {
        if phase != .idle {
            reset()
        }
        activeRequest = request
        portalColor = request.fillColor
        usesReduceMotion = reduceMotion
        phase = reduceMotion ? .pendingSheetDismiss : .entering
    }

    func sheetDidDismiss(reduceMotion: Bool) {
        guard let request = activeRequest else { return }
        usesReduceMotion = reduceMotion
        guard reduceMotion else { return }
        onCommitNavigation?(request)
        phase = .presented
    }

    func commitNavigationBetweenPhases() {
        guard phase == .entering, let request = activeRequest else { return }
        onCommitNavigation?(request)
    }

    func completeEnter() {
        guard phase == .entering else { return }
        phase = .presented
    }

    func beginExit() {
        onDismissNavigation?()
        reset()
    }

    func cancel() {
        reset()
    }

    private func reset() {
        activeRequest = nil
        phase = .idle
        portalColor = .clear
        usesReduceMotion = false
    }
}

// MARK: - Inverse portal mask

/// Punch a center hole in the branded overlay so home/lesson shows through until the hole closes or opens.
private struct PortalHoleMask: View {
    var holeScale: CGFloat
    var holeDiameter: CGFloat
    var holeCenter: CGPoint

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
            Circle()
                .frame(width: holeDiameter, height: holeDiameter)
                .scaleEffect(max(holeScale, 0.001))
                .position(holeCenter)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

// MARK: - Overlay

private func portalCoverDiameter(origin: CGPoint, in size: CGSize) -> CGFloat {
    let corners = [
        CGPoint.zero,
        CGPoint(x: size.width, y: 0),
        CGPoint(x: 0, y: size.height),
        CGPoint(x: size.width, y: size.height),
    ]
    let maxDistance = corners
        .map { hypot($0.x - origin.x, $0.y - origin.y) }
        .max() ?? size.width
    return max(maxDistance * 2.2, 1)
}

struct LessonEntryRevealOverlay: View {
    var coordinator: LessonEntryRevealCoordinator

    @State private var holeScale: CGFloat = 1
    @State private var scheduledWork: [DispatchWorkItem] = []

    var body: some View {
        GeometryReader { proxy in
            if coordinator.isPortalOverlayActive,
               let request = coordinator.activeRequest {
                let portalCenter = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let coverDiameter = portalCoverDiameter(origin: portalCenter, in: proxy.size)

                request.fillColor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .mask(
                        PortalHoleMask(
                            holeScale: holeScale,
                            holeDiameter: coverDiameter,
                            holeCenter: portalCenter
                        )
                    )
            }
        }
        .allowsHitTesting(coordinator.isPortalOverlayActive)
        .ignoresSafeArea()
        .onChange(of: coordinator.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onAppear {
            handlePhaseChange(coordinator.phase)
        }
        .onDisappear {
            cancelScheduledWork()
        }
    }

    private func handlePhaseChange(_ phase: LessonEntryRevealCoordinator.Phase) {
        cancelScheduledWork()

        switch phase {
        case .entering:
            runEnterAnimation()
        case .idle, .presented, .pendingSheetDismiss:
            holeScale = 1
        }
    }

    private func runEnterAnimation() {
        holeScale = 1

        withAnimation(LessonEntryRevealMetrics.collapseInAnimation) {
            holeScale = 0.001
        } completion: {
            coordinator.commitNavigationBetweenPhases()

            withAnimation(LessonEntryRevealMetrics.expandOutAnimation) {
                holeScale = 1
            }
        }

        let completeWork = DispatchWorkItem {
            coordinator.completeEnter()
        }
        scheduledWork.append(completeWork)
        DispatchQueue.main.asyncAfter(
            deadline: .now()
                + LessonEntryRevealMetrics.collapseInDuration
                + LessonEntryRevealMetrics.expandOutDuration,
            execute: completeWork
        )
    }

    private func cancelScheduledWork() {
        scheduledWork.forEach { $0.cancel() }
        scheduledWork.removeAll()
    }
}
