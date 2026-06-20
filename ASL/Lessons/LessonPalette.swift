//
//  LessonPalette.swift
//  ASL
//
//  Palette colour picker shared between the home screen (UnitPalette) and the
//  gameplay views. The home screen owns the full UnitPalette with mascots and
//  shadow ramps; this only exposes the primary colour so lesson chrome can
//  match the unit's brand without leaking the entire palette type.
//

import SwiftUI

enum LessonPalette {
    /// Same colours, same order as `UnitPalette.palettes` on the home screen.
    /// Update both when the home palette changes.
    static let colors: [Color] = [
        Brand.primary,
        Color(red: 0.39, green: 0.77, blue: 0.47),
        Color(red: 0.57, green: 0.49, blue: 0.88),
        Color(red: 0.94, green: 0.57, blue: 0.66),
        Color(red: 0.96, green: 0.61, blue: 0.11),
        Color(red: 0.24, green: 0.69, blue: 0.89),
    ]

    /// Matching deeper shade used as the 3D depth color for raised buttons /
    /// stones. Same order as `colors`; keep in sync with `UnitPalette` on home.
    static let shadows: [Color] = [
        Brand.primaryShadow,
        Color(red: 0.25, green: 0.59, blue: 0.34),
        Color(red: 0.42, green: 0.37, blue: 0.70),
        Color(red: 0.77, green: 0.39, blue: 0.51),
        Color(red: 0.79, green: 0.46, blue: 0.07),
        Color(red: 0.15, green: 0.54, blue: 0.73),
    ]

    static func color(for unit: ASLUnit) -> Color {
        let index = max(0, unit.sortOrder - 1)
        return colors[index % colors.count]
    }

    static func shadow(for unit: ASLUnit) -> Color {
        let index = max(0, unit.sortOrder - 1)
        return shadows[index % shadows.count]
    }
}

// MARK: - Raised unit button

/// Solid 3D slab button matching the home unit header cards: face color +
/// offset shadow ramp, no gradient wash on top.
struct RaisedUnitButtonLabel: View {
    let title: String
    let color: Color
    let depthColor: Color
    var foreground: Color = .white
    let isPressed: Bool
    var height: CGFloat = 56
    var depth: CGFloat = 4
    var isEnabled: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(depthColor)
                .frame(height: height)
                .offset(y: isPressed ? compressedDepth : depth)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
                .frame(height: height)
                .overlay {
                    Text(title)
                        .font(.asl(17, weight: .semibold))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 16)
                }
                .offset(y: faceOffset)
        }
        .frame(maxWidth: .infinity, minHeight: height + depth, alignment: .top)
        .scaleEffect(isPressed ? 0.985 : 1)
        .elevation(.raisedControl(tint: depthColor, isPressed: isPressed))
        .animation(pressAnimation, value: isPressed)
    }

    private var faceOffset: CGFloat {
        isPressed ? depth - compressedDepth : 0
    }

    private var compressedDepth: CGFloat {
        isEnabled ? 1.5 : 4
    }

    private var pressAnimation: Animation {
        isPressed
            ? .easeOut(duration: 0.06)
            : .spring(response: 0.24, dampingFraction: 0.62)
    }
}

struct PressableRaisedUnitButton: View {
    let title: String
    let color: Color
    let depthColor: Color
    var foreground: Color = .white
    var height: CGFloat = 56
    var depth: CGFloat = 4
    var isEnabled: Bool = true
    let action: () -> Void

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    var body: some View {
        RaisedUnitButtonLabel(
            title: title,
            color: color,
            depthColor: depthColor,
            foreground: foreground,
            isPressed: isEnabled && (isPressed || releasePressed),
            height: height,
            depth: depth,
            isEnabled: isEnabled
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    if isEnabled {
                        state = true
                    }
                }
                .onEnded { _ in
                    guard isEnabled else { return }
                    releasePressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        releasePressed = false
                    }
                    Haptics.tap()
                    action()
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityRespondsToUserInteraction(isEnabled)
    }
}
