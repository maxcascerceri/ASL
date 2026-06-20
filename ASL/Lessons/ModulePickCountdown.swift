//
//  ModulePickCountdown.swift
//  ASL
//

import Combine
import SwiftUI

@MainActor
final class ModulePickCountdownController: ObservableObject {
    @Published private(set) var countdown: Int?
    @Published private(set) var choicesVisible = false

    private var workItems: [DispatchWorkItem] = []

    func reset() {
        cancel()
        countdown = nil
        choicesVisible = false
    }

    func cancel() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
    }

    func start(seconds: Int = 3, onReveal: @escaping () -> Void) {
        cancel()
        choicesVisible = false
        guard seconds > 0 else {
            choicesVisible = true
            onReveal()
            return
        }

        countdown = seconds

        for tick in 1..<seconds {
            let next = seconds - tick
            let tickWork = DispatchWorkItem { [weak self] in
                self?.countdown = next
                Haptics.tap()
            }
            workItems.append(tickWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(tick), execute: tickWork)
        }

        let revealWork = DispatchWorkItem { [weak self] in
            self?.countdown = nil
            self?.choicesVisible = true
            onReveal()
        }
        workItems.append(revealWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds), execute: revealWork)
    }

    deinit {
        workItems.forEach { $0.cancel() }
    }
}

struct ModulePickCountdownBanner: View {
    let countdown: Int?
    var minHeight: CGFloat = 64

    var body: some View {
        if let n = countdown {
            Text("\(n)")
                .aslStyle(.celebrationStat, variant: .compact)
                .foregroundStyle(Brand.textPrimary)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: n)
        }
    }
}

/// Digital clock countdown for timed rounds — `0:10` format with a tick pulse each second.
struct SignSprintClockCountdown: View {
    let secondsRemaining: Int
    let totalSeconds: Int

    @State private var tickScale: CGFloat = 1
    @State private var tickOpacity: Double = 1

    private var isUrgent: Bool { secondsRemaining <= 5 && secondsRemaining > 0 }
    private var tint: Color { isUrgent ? PracticeTheme.timerUrgent : Brand.textPrimary }
    private var minutes: Int { max(0, secondsRemaining) / 60 }
    private var seconds: Int { max(0, secondsRemaining) % 60 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(minutes)")
                    .frame(minWidth: 28, alignment: .trailing)

                Text(":")
                    .padding(.horizontal, 2)
                    .offset(y: -2)

                Text(String(format: "%02d", seconds))
                    .frame(minWidth: 44, alignment: .leading)
                    .scaleEffect(tickScale)
                    .opacity(tickOpacity)
            }
            .font(.asl(.celebrationHeadline, variant: .compact))
            .monospacedDigit()
            .foregroundStyle(tint)

            SignSprintClockTickBar(
                progress: progress,
                tint: tint
            )
        }
        .frame(maxWidth: .infinity)
        .onChange(of: secondsRemaining) { oldValue, newValue in
            guard oldValue != newValue else { return }
            pulseTick()
        }
    }

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(max(0, secondsRemaining)) / CGFloat(totalSeconds)
    }

    private func pulseTick() {
        tickScale = 1.14
        tickOpacity = 0.72
        withAnimation(.spring(response: 0.18, dampingFraction: 0.48)) {
            tickScale = 1
            tickOpacity = 1
        }
    }
}

private struct SignSprintClockTickBar: View {
    let progress: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Brand.divider.opacity(0.55))

                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 56)
        .animation(.linear(duration: 0.95), value: progress)
    }
}
