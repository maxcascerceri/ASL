//
//  RaisedCardPress.swift
//  ASL
//

import SwiftUI

/// Shared press metrics — delegates to the premium card system.
enum RaisedCardMetrics {
    static var depth: CGFloat { PremiumCardMetrics.depth }
    static var pressedDepthOffset: CGFloat { PremiumCardMetrics.pressedDepthOffset }
    static var pressedFaceOffset: CGFloat { PremiumCardMetrics.pressedFaceOffset }
    static var pressedScale: CGFloat { PremiumCardMetrics.pressedScale }

    static var pressAnimation: Animation { PremiumCardMetrics.pressAnimation }
}

/// Standard `ButtonStyle` for raised cards in scroll views.
struct RaisedCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.raisedCardPressed, configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

/// Shared raised card body for neutral / white surfaces.
struct RaisedCardShell<Content: View>: View {
    let fill: Color
    let depthColor: Color
    var cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusCompact
    var isPressed: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        PremiumWhiteCard(fill: fill, cornerRadius: cornerRadius, isPressed: isPressed) {
            content()
        }
    }
}

private struct RaisedCardPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var raisedCardPressed: Bool {
        get { self[RaisedCardPressedKey.self] }
        set { self[RaisedCardPressedKey.self] = newValue }
    }
}
