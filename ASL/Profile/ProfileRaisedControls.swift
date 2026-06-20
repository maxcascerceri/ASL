//
//  ProfileRaisedControls.swift
//  ASL
//

import SwiftUI

struct ProfileRaisedCircleButton<Label: View>: View {
    let isPressed: Bool
    let size: CGFloat
    let depth: CGFloat
    let face: Color
    let shadow: Color
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(shadow)
                .frame(width: size, height: size)
                .offset(y: isPressed ? 1 : depth)

            Circle()
                .fill(face)
                .frame(width: size, height: size)
                .overlay { label() }
                .offset(y: isPressed ? depth - 1 : 0)
        }
        .frame(width: size, height: size + depth, alignment: .top)
    }
}

struct ProfileRaisedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.profileRaisedPressed, configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ProfileRaisedPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var profileRaisedPressed: Bool {
        get { self[ProfileRaisedPressedKey.self] }
        set { self[ProfileRaisedPressedKey.self] = newValue }
    }
}
