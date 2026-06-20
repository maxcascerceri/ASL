//
//  ChoiceTile.swift
//  ASL
//
//  Word-choice button shared by every gameplay view. Owns the full feedback
//  state machine described in the design plan:
//
//    rest         -> press (scale 0.95, 100ms easeOut)
//    press        -> spring back (response 0.25, damping 0.6)
//    correct      -> lesson green + checkmark
//    wrong        -> soft coral + 3x shake at 80ms each
//    correctGlow  -> green outline on the answer the user missed
//    dimmed       -> faded sibling tiles during wrong-answer feedback
//
//  No "Wrong" / "Incorrect" labels anywhere - the colour + motion does all
//  the punishment-free work.
//

import SwiftUI

enum ChoiceTileState: Equatable {
    case rest
    case correct
    case wrong
    case correctGlow
    case dimmed
    case selected
}

struct ChoiceTile: View {
    let label: String
    let state: ChoiceTileState
    let palette: Color
    let paletteShadow: Color
    let action: () -> Void

    @State private var shakeProgress: CGFloat = 0
    @State private var pulse: Bool = false

    private static let cornerRadius: CGFloat = 22
    private static let minHeight: CGFloat = 60

    var body: some View {
        PressableChoiceTileButton(isEnabled: isInteractive, action: handleTap) { isPressed in
            tileBody(isPressed: isPressed)
        }
        .modifier(ShakeEffect(progress: shakeProgress))
        .scaleEffect(pulse ? 1.04 : 1.0)
        .animation(
            (state == .correct || state == .wrong || state == .correctGlow) ? nil : .easeInOut(duration: 0.2),
            value: state
        )
        .onChange(of: state) { _, newValue in
            respond(to: newValue)
        }
    }

    private func tileBody(isPressed: Bool) -> some View {
        Text(label)
            .font(LessonQuestionLayout.choiceFont)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: Self.minHeight)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .elevation(state == .rest || state == .dimmed || state == .selected ? .insetField : .none)
            .overlay(alignment: .trailing) { checkmark }
            .frame(maxWidth: .infinity, minHeight: Self.minHeight)
            .opacity(opacity)
            .scaleEffect(selectionScale * (isPressed ? 0.97 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .animation(
                isPressed ? .easeOut(duration: 0.06) : .spring(response: 0.24, dampingFraction: 0.62),
                value: isPressed
            )
    }

    private var selectionScale: CGFloat {
        state == .selected ? 1.02 : 1
    }

    private var isInteractive: Bool {
        state == .rest || state == .correctGlow || state == .selected
    }

    @ViewBuilder
    private var checkmark: some View {
        if state == .correct {
            Image(systemName: "checkmark.circle.fill")
                .font(.asl(LessonQuestionLayout.feedbackAnswerFontSize, weight: LessonQuestionLayout.feedbackAnswerWeight))
                .foregroundStyle(Color.lessonGreen)
                .padding(.trailing, 14)
                .transaction { $0.animation = nil }
        }
    }

    private func handleTap() {
        Haptics.tap()
        LessonSounds.play(.tap)
        action()
    }

    private func respond(to newValue: ChoiceTileState) {
        switch newValue {
        case .correct:
            withAnimation(.easeOut(duration: 0.12)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    pulse = false
                }
            }
        case .wrong:
            shakeProgress = 0
            withAnimation(.linear(duration: 0.24)) { shakeProgress = 3 }
        case .rest, .correctGlow, .dimmed, .selected:
            pulse = false
        }
    }

    // MARK: - Visual derivations

    private var fillColor: Color {
        switch state {
        case .rest, .dimmed, .selected:
            return Color.white
        case .correctGlow:
            return Color.lessonCorrectPanel
        case .correct:
            return Color.lessonCorrectPanel
        case .wrong:
            return Color.lessonErrorPanel
        }
    }

    private var borderColor: Color {
        switch state {
        case .rest, .dimmed:
            return Brand.divider.opacity(0.95)
        case .selected:
            return palette
        case .correct, .correctGlow:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .rest, .dimmed:
            return 1.5
        case .selected, .correctGlow, .correct, .wrong:
            return 3
        }
    }

    private var textColor: Color {
        switch state {
        case .correct:
            return Color.lessonCorrectText
        case .wrong:
            return Color.lessonWrongText
        case .selected:
            return Brand.textPrimary
        case .correctGlow:
            return Color.lessonCorrectText
        case .rest, .dimmed:
            return Brand.textPrimary
        }
    }

    private var opacity: Double {
        state == .dimmed ? 0.55 : 1.0
    }
}

private struct PressableChoiceTileButton<Label: View>: View {
    let isEnabled: Bool
    let action: () -> Void
    let label: (Bool) -> Label

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    init(isEnabled: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping (Bool) -> Label) {
        self.isEnabled = isEnabled
        self.action = action
        self.label = label
    }

    var body: some View {
        label(isEnabled && (isPressed || releasePressed))
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
                        action()
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Shake effect

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var amplitude: CGFloat = 6

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(progress * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Lesson palette colours

extension Color {
    /// Pale mint tray / correct-tile fill.
    static let lessonCorrectPanel = Color(red: 207 / 255, green: 247 / 255, blue: 227 / 255)

    /// Headline on correct feedback.
    static let lessonCorrectText = Color(red: 18 / 255, green: 138 / 255, blue: 87 / 255)

    /// Green continue button and correct accents.
    static let lessonGreen = Color(red: 28 / 255, green: 186 / 255, blue: 117 / 255)

    static let lessonGreenShadow = Color(red: 19 / 255, green: 155 / 255, blue: 96 / 255)

    /// Headline on wrong feedback.
    static let lessonWrongText = Color(red: 227 / 255, green: 48 / 255, blue: 58 / 255)

    /// Coral continue button when incorrect.
    static let lessonCoralButton = Color(red: 235 / 255, green: 61 / 255, blue: 69 / 255)

    static let lessonCoralButtonShadow = Color(red: 206 / 255, green: 38 / 255, blue: 48 / 255)

    /// Coral for flashes and legacy call sites.
    static let lessonCoral = Color(red: 235 / 255, green: 66 / 255, blue: 74 / 255)

    static let lessonCoralShadow = Color(red: 210 / 255, green: 40 / 255, blue: 50 / 255)

    /// Quiet neutral surface for video plates and inline blanks.
    static let lessonSurface = Brand.neutralSurface

    static let lessonSuccessPanel = lessonCorrectPanel

    /// Pale blush tray / wrong-tile fill.
    static let lessonErrorPanel = Color(red: 252 / 255, green: 236 / 255, blue: 236 / 255)
}
