//
//  Haptics.swift
//  ASL
//
//  Tiny wrapper around UIKit haptic generators so every gameplay view can fire
//  the right feedback in a single call. Generators are short-lived and prepared
//  immediately before use to minimise initial latency.
//

import UIKit

enum Haptics {
    private static var isEnabled: Bool { ASLSettings.hapticsEnabled }

    /// Light tap whenever the user touches a button or choice tile.
    static func tap() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Success bump used when a correct answer lands.
    static func correct() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Soft warning. Intentionally not `.error` so the device doesn't punish
    /// the user; this is the "try again" beat.
    static func wrong() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Tiny pulse to accompany progress-bar movement.
    static func progressBump() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Per-second pulse when a speed-round timer enters the final five seconds.
    static func speedRoundUrgentTick() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Single soft impact for mid-lesson streak milestones.
    static func streakMilestone() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 2x medium impacts 100ms apart. Fired when a single stone finishes.
    static func stoneComplete() {
        guard isEnabled else { return }
        burst(style: .medium, count: 2, intervalMs: 100)
    }

    /// 3x medium impacts 150ms apart. Fired when the whole unit unlocks.
    static func unitComplete() {
        guard isEnabled else { return }
        burst(style: .medium, count: 3, intervalMs: 150)
    }

    private static func burst(style: UIImpactFeedbackGenerator.FeedbackStyle,
                              count: Int,
                              intervalMs: Int) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        for i in 0..<count {
            let delay = Double(i) * Double(intervalMs) / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                generator.impactOccurred()
            }
        }
    }
}
