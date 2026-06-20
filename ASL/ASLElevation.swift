//
//  ASLElevation.swift
//  ASL
//
//  Layered atmospheric shadows for premium material depth.
//

import SwiftUI

enum Elevation {
    /// Cool neutral base for shadow tinting — softer than pure black on brand chrome.
    private static let ink = Brand.ink

    struct Layer {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum StoneState {
        case locked
        case current
        case completed
    }

    /// Predefined elevation recipes used across the app.
    enum Recipe {
        case none
        case lessonStone(state: StoneState, tint: Color, isPressed: Bool)
        case chapterCard(tint: Color)
        case sectionPill(tint: Color)
        case floatingBubble(accent: Color)
        case raisedControl(tint: Color, isPressed: Bool)
        case phasePlaque(tint: Color, isPressed: Bool)
        case navigationPanel
        case navigationBar
        case insetField
        case sheetModal
    }

    static func layers(for recipe: Recipe) -> [Layer] {
        switch recipe {
        case .none:
            return []
        case let .lessonStone(state, tint, isPressed):
            return lessonStoneLayers(state: state, tint: tint, isPressed: isPressed)
        case let .chapterCard(tint):
            return chapterCardLayers(tint: tint)
        case let .sectionPill(tint):
            return sectionPillLayers(tint: tint)
        case let .floatingBubble(accent):
            return floatingBubbleLayers(accent: accent)
        case let .raisedControl(tint, isPressed):
            return raisedControlLayers(tint: tint, isPressed: isPressed)
        case let .phasePlaque(tint, isPressed):
            return phasePlaqueLayers(tint: tint, isPressed: isPressed)
        case .navigationPanel:
            return navigationPanelLayers()
        case .navigationBar:
            return navigationBarLayers()
        case .insetField:
            return insetFieldLayers()
        case .sheetModal:
            return sheetModalLayers()
        }
    }

    // MARK: - Recipes

    private static func lessonStoneLayers(state: StoneState, tint: Color, isPressed: Bool) -> [Layer] {
        let intensity: Double = switch state {
        case .locked: 0.55
        case .current: 0.82
        case .completed: 1.0
        }
        let scale = isPressed ? 0.42 : 1.0

        return [
            Layer(
                color: ink.opacity(0.038 * intensity * scale),
                radius: isPressed ? 1.5 : 2.5,
                x: 0,
                y: isPressed ? 1 : 1.25
            ),
            Layer(
                color: tint.opacity(0.058 * intensity * scale),
                radius: isPressed ? 6 : 11,
                x: 0,
                y: isPressed ? 2.5 : 6
            ),
            Layer(
                color: ink.opacity(isPressed ? 0 : 0.016 * intensity),
                radius: 22,
                x: 0,
                y: 14
            ),
        ]
    }

    private static func chapterCardLayers(tint: Color) -> [Layer] {
        [
            Layer(color: tint.opacity(0.05), radius: 10, x: 0, y: 4),
            Layer(color: ink.opacity(0.022), radius: 20, x: 0, y: 9),
        ]
    }

    private static func sectionPillLayers(tint: Color) -> [Layer] {
        [
            Layer(color: tint.opacity(0.045), radius: 6, x: 0, y: 2.5),
            Layer(color: ink.opacity(0.018), radius: 12, x: 0, y: 5),
        ]
    }

    private static func floatingBubbleLayers(accent: Color) -> [Layer] {
        [
            Layer(color: ink.opacity(0.032), radius: 1.5, x: 0, y: 0.75),
            Layer(color: accent.opacity(0.048), radius: 9, x: 0, y: 3.5),
            Layer(color: ink.opacity(0.016), radius: 16, x: 0, y: 7),
        ]
    }

    private static func raisedControlLayers(tint: Color, isPressed: Bool) -> [Layer] {
        let scale = isPressed ? 0.48 : 1.0

        return [
            Layer(
                color: tint.opacity(0.052 * scale),
                radius: isPressed ? 2.5 : 4,
                x: 0,
                y: isPressed ? 1 : 1.75
            ),
            Layer(
                color: tint.opacity(0.04 * scale),
                radius: isPressed ? 7 : 13,
                x: 0,
                y: isPressed ? 2.5 : 5
            ),
            Layer(
                color: ink.opacity(0.02 * scale),
                radius: isPressed ? 12 : 22,
                x: 0,
                y: isPressed ? 5 : 10
            ),
        ]
    }

    private static func phasePlaqueLayers(tint: Color, isPressed: Bool) -> [Layer] {
        raisedControlLayers(tint: tint, isPressed: isPressed)
    }

    private static func navigationPanelLayers() -> [Layer] {
        [
            Layer(color: ink.opacity(0.024), radius: 22, x: 0, y: -2),
            Layer(color: ink.opacity(0.04), radius: 8, x: 0, y: -4.5),
        ]
    }

    private static func navigationBarLayers() -> [Layer] {
        [
            Layer(color: ink.opacity(0.018), radius: 14, x: 0, y: -2.5),
            Layer(color: ink.opacity(0.034), radius: 4, x: 0, y: -1),
        ]
    }

    private static func insetFieldLayers() -> [Layer] {
        [
            Layer(color: ink.opacity(0.028), radius: 1.5, x: 0, y: 0.75),
            Layer(color: Brand.primary.opacity(0.035), radius: 8, x: 0, y: 3),
        ]
    }

    private static func sheetModalLayers() -> [Layer] {
        [
            Layer(color: ink.opacity(0.038), radius: 26, x: 0, y: 14),
            Layer(color: ink.opacity(0.024), radius: 10, x: 0, y: 5),
        ]
    }
}

// MARK: - View modifier

private struct LayeredElevationModifier: ViewModifier {
    let layers: [Elevation.Layer]

    func body(content: Content) -> some View {
        content.modifier(RecursiveShadowModifier(layers: layers, index: 0))
    }
}

private struct RecursiveShadowModifier: ViewModifier {
    let layers: [Elevation.Layer]
    let index: Int

    func body(content: Content) -> some View {
        if index >= layers.count {
            content
        } else {
            let layer = layers[index]
            content
                .shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y)
                .modifier(RecursiveShadowModifier(layers: layers, index: index + 1))
        }
    }
}

extension View {
    func elevation(_ recipe: Elevation.Recipe) -> some View {
        modifier(LayeredElevationModifier(layers: Elevation.layers(for: recipe)))
    }

    /// Gentle idle float around the view's resting position (layout unchanged).
    func subtleVerticalBob(isActive: Bool = true, amplitude: CGFloat = 4, duration: Double = 1.2) -> some View {
        modifier(SubtleVerticalBobModifier(isActive: isActive, amplitude: amplitude, duration: duration))
    }
}

private struct SubtleVerticalBobModifier: ViewModifier {
    let isActive: Bool
    let amplitude: CGFloat
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                // Match the old easeInOut autoreverse cadence (~`duration` per half-cycle).
                let phase = sin(elapsed * .pi * 2 / (duration * 2))
                content.offset(y: amplitude * phase)
            }
        } else {
            content
        }
    }
}
