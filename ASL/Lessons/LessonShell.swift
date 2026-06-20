//
//  LessonShell.swift
//  ASL
//
//  Chrome shared by every gameplay view: top progress bar with bump
//  animation, close X with confirm-discard alert, neutral quiet background.
//  Stone views just pass their question content as the body.
//

import AVFoundation
import SwiftUI

enum LessonQuestionLayout {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 22
    static let choiceSpacing: CGFloat = 14

    // MARK: - Typography (uniform across module + stone lessons)

    /// Primary step instruction — one size for every lesson step.
    static let promptFontSize: CGFloat = 21
    static let promptWeight: Font.Weight = .semibold
    /// Target word or phrase embedded in a prompt (e.g. "Which video shows Hello?").
    static let promptEmphasisWeight: Font.Weight = .semibold

    /// Secondary copy under a prompt (teach meta, self-sign hints, feedback context).
    static let subtitleFontSize: CGFloat = 16
    static let subtitleWeight: Font.Weight = .regular

    /// Answer choice tiles.
    static let choiceFontSize: CGFloat = 17
    static let choiceWeight: Font.Weight = .semibold

    /// Match-pair translation chips and inline fill-slot chips.
    static let chipFontSize: CGFloat = 17
    static let chipWeight: Font.Weight = .semibold

    /// Teach-step eyebrow above the video.
    static let teachEyebrowFontSize: CGFloat = 17
    static let teachEyebrowWeight: Font.Weight = .medium

    /// Large taught word on teach beats.
    static let teachWordFontSize: CGFloat = 32
    static let teachWordWeight: Font.Weight = .semibold

    /// Inline sentence fragments (fill gap, fill slot, checkpoint).
    static let sentenceFontSize: CGFloat = 21
    static let sentenceWeight: Font.Weight = .semibold

    /// Floating microcopy (phase review round banner, match-pairs hints).
    static let microcopyFontSize: CGFloat = 17
    static let microcopyWeight: Font.Weight = .semibold

    /// Bottom tray feedback headline.
    static let feedbackHeadlineFontSize: CGFloat = 20
    static let feedbackHeadlineWeight: Font.Weight = .semibold

    /// Bottom tray feedback icon.
    static let feedbackIconFontSize: CGFloat = 20
    static let feedbackIconWeight: Font.Weight = .semibold

    /// “Correct answer:” label in the feedback tray.
    static let feedbackLabelFontSize: CGFloat = 16
    static let feedbackLabelWeight: Font.Weight = .regular

    /// Answer word in the feedback tray.
    static let feedbackAnswerFontSize: CGFloat = 17
    static let feedbackAnswerWeight: Font.Weight = .semibold

    /// Disabled tray hint copy.
    static let trayHintFontSize: CGFloat = 16
    static let trayHintWeight: Font.Weight = .regular

    /// Continue / Check answer / Choose an answer.
    static let trayButtonFont: Font = .asl(.button, variant: .compact)

    static var promptFont: Font { .aslReading(promptFontSize, weight: promptWeight) }
    static var subtitleFont: Font { .aslReading(subtitleFontSize, weight: subtitleWeight) }
    static var choiceFont: Font { .aslReading(choiceFontSize, weight: choiceWeight) }
    static var chipFont: Font { .aslReading(chipFontSize, weight: chipWeight) }
    static var teachEyebrowFont: Font { .aslReading(teachEyebrowFontSize, weight: teachEyebrowWeight) }
    static var teachWordFont: Font { .asl(teachWordFontSize, weight: teachWordWeight, design: .ui) }
    static var sentenceFont: Font { .aslReading(sentenceFontSize, weight: sentenceWeight) }
    static var microcopyFont: Font { .aslReading(microcopyFontSize, weight: microcopyWeight) }
    static var feedbackHeadlineFont: Font { .aslReading(feedbackHeadlineFontSize, weight: feedbackHeadlineWeight) }
    static var feedbackIconFont: Font { .aslReading(feedbackIconFontSize, weight: feedbackIconWeight) }
    static var feedbackLabelFont: Font { .aslReading(feedbackLabelFontSize, weight: feedbackLabelWeight) }
    static var feedbackAnswerFont: Font { .aslReading(feedbackAnswerFontSize, weight: feedbackAnswerWeight) }
    static var trayHintFont: Font { .aslReading(trayHintFontSize, weight: trayHintWeight) }

    /// Fit two stacked video choices inside the module lesson content lane.
    static func stackedWordPickVideoCardHeight(
        availableHeight: CGFloat,
        includesPhraseSubtitle: Bool,
        preferredHeight: CGFloat = wordPickVideoCardHeight
    ) -> CGFloat {
        guard availableHeight > 0 else { return preferredHeight }
        let promptReserve: CGFloat = includesPhraseSubtitle ? 96 : 72
        let sectionSpacing: CGFloat = 14
        let interCardSpacing: CGFloat = 10
        let usable = availableHeight - promptReserve - sectionSpacing - interCardSpacing
        let perCard = usable / 2
        return min(preferredHeight, max(wordPickVideoCardHeightMinimum, perCard))
    }

    /// Aligns with `LessonActionTrayLayout.effectiveBottomPadding` for legacy call sites.
    static let bottomPadding: CGFloat = LessonActionTrayLayout.effectiveBottomPadding
    static let videoHeight: CGFloat = 320
    static let videoHeightCompact: CGFloat = 260
    /// Main recording playback on the Your Turn review step.
    static let yourTurnReviewVideoHeight: CGFloat = 460
    /// Stacked A/B cards on the match-this-sign (`wordPickVideo`) step.
    static let wordPickVideoCardHeight: CGFloat = 230
    static let wordPickVideoCardHeightMinimum: CGFloat = 156
    static let videoCornerRadius: CGFloat = SignVideoCardMetrics.cornerRadius
}

extension Text {
    func lessonPromptStyle() -> some View {
        font(LessonQuestionLayout.promptFont)
            .foregroundStyle(Brand.textPrimary)
            .multilineTextAlignment(.center)
    }

    func lessonSubtitleStyle() -> some View {
        font(LessonQuestionLayout.subtitleFont)
            .foregroundStyle(Brand.secondaryLabel)
            .multilineTextAlignment(.center)
    }
}

/// Shared bottom chrome metrics — module tray and stone “Done” buttons use the same lane.
enum LessonActionTrayLayout {
    /// Tray height when feedback copy is visible (correct / wrong).
    static let expandedReservedHeight: CGFloat = 212
    /// Tray height for waiting, check-answer, and continue-only states.
    static let compactReservedHeight: CGFloat = 104
    static let reservedHeight: CGFloat = expandedReservedHeight
    static func reservedHeight(for state: ModuleNavigationButtonState) -> CGFloat {
        state.feedback == nil ? compactReservedHeight : expandedReservedHeight
    }
    static func contentInsetAboveTray(for state: ModuleNavigationButtonState) -> CGFloat {
        reservedHeight(for: state)
    }
    /// Content inset above the pinned tray (matches reserved tray band).
    static var contentInsetAboveTray: CGFloat { compactReservedHeight }
    static let trayTopPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 20
    static let buttonHeight: CGFloat = 56
    /// Base padding above the home indicator before module vertical nudge.
    static let trayBottomPadding: CGFloat = 38
    static let verticalNudge: CGFloat = 10
    static var effectiveBottomPadding: CGFloat { trayBottomPadding - verticalNudge + LessonPrimaryButtonMetrics.depth }
    static let feedbackToButtonSpacing: CGFloat = 14
    static let feedbackPanelTopPadding: CGFloat = 10
    /// Gap between the bottom of choice tiles and the reserved tray band.
    static let choiceStackPaddingAboveTray: CGFloat = 8
}

/// Physical depth + press offsets for lesson tray CTAs (Continue, Check answer, etc.).
enum LessonPrimaryButtonMetrics {
    static let depth: CGFloat = 5
    static let pressedFaceOffset: CGFloat = 3
    static let pressedDepthOffset: CGFloat = 1.5
    static let pressedScale: CGFloat = 0.985
}

/// Primary CTA pinned to the lesson action lane (Continue, Done, Check answer, etc.).
struct LessonPinnedPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var color: Color = Brand.primary
    let action: () -> Void

    var body: some View {
        PressableLessonPrimaryButton(
            title: title,
            isEnabled: isEnabled,
            color: color,
            action: action
        )
        .padding(.horizontal, LessonActionTrayLayout.horizontalPadding)
        .padding(.bottom, LessonActionTrayLayout.effectiveBottomPadding)
    }
}

struct LessonChromeIconButton: View {
    let systemName: String
    var tint: Color = Brand.secondaryLabel
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.asl(14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Brand.divider.opacity(0.55))
                )
        }
        .buttonStyle(.plain)
    }
}

struct LessonVideoStage<Overlay: View>: View {
    @ObservedObject var controller: LessonPlayerController
    var wordId: String?
    var store: ASLDataStore?
    var height: CGFloat = LessonQuestionLayout.videoHeight
    var cornerRadius: CGFloat = SignVideoCardMetrics.cornerRadius
    var placeholderColor: Color = Brand.homeBackground
    /// Shows the green turtle slow-mo control. Only the single primary "sign area"
    /// video should set this; answer-choice cards do not.
    var showsControls: Bool = false
    @ViewBuilder var overlay: () -> Overlay

    init(
        controller: LessonPlayerController,
        wordId: String? = nil,
        store: ASLDataStore? = nil,
        height: CGFloat = LessonQuestionLayout.videoHeight,
        cornerRadius: CGFloat = SignVideoCardMetrics.cornerRadius,
        placeholderColor: Color = Brand.homeBackground,
        showsControls: Bool = false,
        @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.controller = controller
        self.wordId = wordId
        self.store = store
        self.height = height
        self.cornerRadius = cornerRadius
        self.placeholderColor = placeholderColor
        self.showsControls = showsControls
        self.overlay = overlay
    }

    private var showsFilmPlaceholder: Bool {
        guard let wordId, let store else { return false }
        if ASLPendingFilmCatalog.shouldShowPlaceholder(for: wordId, store: store) {
            return true
        }
        return ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store)
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        if showsControls, !showsFilmPlaceholder {
            SignVideoControlsOverlay(controller: controller)
        }
    }

    var body: some View {
        Group {
            if showsFilmPlaceholder, let wordId, let store {
                SignFilmPlaceholder(
                    title: ASLPendingFilmCatalog.title(for: wordId, store: store),
                    height: height,
                    cornerRadius: cornerRadius,
                    style: .stage
                )
                .elevation(.insetField)
                .overlay { overlay() }
                .overlay { controlsOverlay }
            } else {
                LessonVideoPlayer(
                    controller: controller,
                    cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                    videoGravity: .resizeAspectFill,
                    placeholderColor: placeholderColor
                )
                .padding(SignVideoCardMetrics.innerPadding)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(placeholderColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
                }
                .elevation(.insetField)
                .overlay { overlay() }
                .overlay { controlsOverlay }
            }
        }
        .lessonSignAreaLayoutStable()
    }
}

extension View {
    /// Prevents sign/video containers from interpolating position or size during
    /// sibling state changes (tray feedback, step transitions, selection).
    func lessonSignAreaLayoutStable() -> some View {
        transaction { $0.disablesAnimations = true }
    }
}

struct LessonPromptLabel: View {
    let text: String
    var fontSize: CGFloat = LessonQuestionLayout.promptFontSize
    var emphasizedSegment: String? = nil
    var useInstructionWeight: Bool = false
    var subtitle: String? = nil
    var subtitleFontSize: CGFloat = 24
    var subtitleWeight: Font.Weight = .semibold
    var eyebrow: String? = nil
    var eyebrowColor: Color = Brand.secondaryLabel
    /// Color for the target vocabulary word embedded in the prompt (defaults to brand primary).
    var emphasisColor: Color = Brand.primary
    /// When set, styles the subtitle line (e.g. phrase label under "Match this phrase.").
    var subtitleForeground: Color? = nil

    var body: some View {
        VStack(spacing: eyebrow == nil ? 6 : 10) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(LessonQuestionLayout.teachEyebrowFont)
                    .tracking(1.1)
                    .foregroundStyle(eyebrowColor)
            }

            Group {
                if let emphasized = emphasizedSegment,
                   !emphasized.isEmpty,
                   text.contains(emphasized) {
                    emphasizedPrompt(emphasized: emphasized)
                } else {
                    Text(text)
                        .font(.aslReading(fontSize, weight: LessonQuestionLayout.promptWeight))
                }
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.aslReading(subtitleFontSize, weight: subtitleWeight))
                    .foregroundStyle(subtitleForeground ?? Brand.textPrimary)
            }
        }
        .foregroundStyle(Brand.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private func emphasizedPrompt(emphasized: String) -> Text {
        guard let range = Self.emphasisRange(in: text, segment: emphasized) else {
            return Text(text).font(.aslReading(fontSize, weight: LessonQuestionLayout.promptWeight))
        }

        let prefix = String(text[..<range.lowerBound])
        let emphasizedPart = String(text[range])
        let suffix = String(text[range.upperBound...])

        return Text(prefix).font(.aslReading(fontSize, weight: LessonQuestionLayout.promptWeight))
            + Text(emphasizedPart)
                .font(.aslReading(fontSize, weight: LessonQuestionLayout.promptEmphasisWeight))
                .foregroundStyle(emphasisColor)
            + Text(suffix).font(.aslReading(fontSize, weight: LessonQuestionLayout.promptWeight))
    }

    /// Headlines that intentionally name the target word (see `ASLLessonPromptFraming.wordPickVideoTemplates`).
    private static let intentionalAnswerPromptPrefixes = [
        "Pick out ",
        "Find ",
        "Choose ",
        "Which video shows ",
        "Match this sign: ",
    ]

    /// True when the prompt headline is meant to highlight the vocabulary word itself.
    static func promptIntentionallyNamesAnswer(_ wordLabel: String, in prompt: String) -> Bool {
        guard !wordLabel.isEmpty else { return false }
        for prefix in intentionalAnswerPromptPrefixes {
            guard prompt.lowercased().hasPrefix(prefix.lowercased()) else { continue }
            let suffix = String(prompt.dropFirst(prefix.count))
            let trimmed = suffix.trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
            return trimmed.caseInsensitiveCompare(wordLabel) == .orderedSame
        }
        return false
    }

    /// Finds the first whole-word occurrence of `segment` in `text`.
    static func emphasisRange(in text: String, segment: String) -> Range<String.Index>? {
        guard !segment.isEmpty else { return nil }

        let escaped = NSRegularExpression.escapedPattern(for: segment)
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\(escaped)\\b",
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let fullRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return range
    }

    /// Returns the prompt substring to emphasize for a target vocabulary label, if present.
    static func emphasisSegment(in text: String, wordLabel: String) -> String? {
        guard !wordLabel.isEmpty else { return nil }
        guard let range = emphasisRange(in: text, segment: wordLabel) else { return nil }
        return String(text[range])
    }

    /// Like `emphasisSegment(in:wordLabel:)`, but only for headlines that name the answer on purpose.
    static func emphasisSegment(forPrompt prompt: String, wordLabel: String, in text: String? = nil) -> String? {
        guard promptIntentionallyNamesAnswer(wordLabel, in: prompt) else { return nil }
        return emphasisSegment(in: text ?? prompt, wordLabel: wordLabel)
    }
}

struct LessonWatchPickSection<Overlay: View>: View {
    @ObservedObject var controller: LessonPlayerController
    let prompt: String
    var emphasizedSegment: String? = nil
    var emphasisColor: Color = Brand.primary
    var videoHeight: CGFloat = LessonQuestionLayout.videoHeight
    @ViewBuilder var overlay: () -> Overlay

    init(
        controller: LessonPlayerController,
        prompt: String,
        emphasizedSegment: String? = nil,
        emphasisColor: Color = Brand.primary,
        videoHeight: CGFloat = LessonQuestionLayout.videoHeight,
        @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.controller = controller
        self.prompt = prompt
        self.emphasizedSegment = emphasizedSegment
        self.emphasisColor = emphasisColor
        self.videoHeight = videoHeight
        self.overlay = overlay
    }

    var body: some View {
        VStack(spacing: LessonQuestionLayout.sectionSpacing) {
            LessonPromptLabel(
                text: prompt,
                emphasizedSegment: emphasizedSegment,
                emphasisColor: emphasisColor
            )
            LessonVideoStage(controller: controller, height: videoHeight, overlay: overlay)
        }
    }
}

/// Standard lesson step layout: prompt on top, media, inline controls, then bottom tray CTA.
struct LessonStepStack<Title: View, Media: View, Controls: View>: View {
    var spacing: CGFloat = LessonQuestionLayout.sectionSpacing
    var fillsRemainingSpace: Bool = false
    @ViewBuilder var title: () -> Title
    @ViewBuilder var media: () -> Media
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(spacing: spacing) {
            title()
            media()
            controls()
            if fillsRemainingSpace {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct LessonPrimaryButtonLabel: View {
    let title: String
    var isEnabled: Bool
    var color: Color = Brand.primary
    var depthColor: Color? = nil
    var isPressed: Bool

    private var height: CGFloat { LessonActionTrayLayout.buttonHeight }
    private var depth: CGFloat { LessonPrimaryButtonMetrics.depth }

    private var faceColor: Color {
        isEnabled ? color : Brand.divider.opacity(0.65)
    }

    private var resolvedDepthColor: Color {
        guard isEnabled else { return Brand.divider.opacity(0.45) }
        if let depthColor { return depthColor }
        return PremiumCardStyle.softDepth(for: color, mix: 0.34)
    }

    private var faceOffset: CGFloat {
        guard isEnabled, isPressed else { return 0 }
        return LessonPrimaryButtonMetrics.pressedFaceOffset
    }

    private var depthOffset: CGFloat {
        guard isEnabled else { return 0 }
        return isPressed ? LessonPrimaryButtonMetrics.pressedDepthOffset : depth
    }

    var body: some View {
        Group {
            if isEnabled {
                raisedButton
            } else {
                flatButton
            }
        }
        .animation(pressAnimation, value: isPressed)
    }

    private var raisedButton: some View {
        ZStack(alignment: .top) {
            Capsule(style: .continuous)
                .fill(resolvedDepthColor)
                .frame(height: height)
                .offset(y: depthOffset)

            Capsule(style: .continuous)
                .fill(faceColor)
                .frame(height: height)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .overlay {
                    Text(title)
                        .font(LessonQuestionLayout.trayButtonFont)
                        .foregroundStyle(Color.white)
                }
                .offset(y: faceOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height + depth, alignment: .top)
        .scaleEffect(isPressed ? LessonPrimaryButtonMetrics.pressedScale : 1)
        .elevation(.raisedControl(tint: resolvedDepthColor, isPressed: isPressed))
    }

    private var flatButton: some View {
        Text(title)
            .font(LessonQuestionLayout.trayButtonFont)
            .foregroundStyle(Brand.secondaryLabel.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                Capsule(style: .continuous)
                    .fill(faceColor)
            )
    }

    private var pressAnimation: Animation {
        isPressed
            ? .easeOut(duration: 0.06)
            : .spring(response: 0.24, dampingFraction: 0.62)
    }
}

struct PressableLessonPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var color: Color = Brand.primary
    var depthColor: Color? = nil
    let action: () -> Void

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    var body: some View {
        LessonPrimaryButtonLabel(
            title: title,
            isEnabled: isEnabled,
            color: color,
            depthColor: depthColor,
            isPressed: isEnabled && (isPressed || releasePressed)
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

struct LessonShell<Content: View>: View {
    let progress: Double
    let palette: Color
    let paletteShadow: Color
    var showReset: Bool = false
    var showsCloseButton: Bool = true
    var leaveConfirmMessage: String = "Your progress is saved. You can pick up where you left off."
    var onLeave: (() -> Void)? = nil
    var onReset: (() -> Void)? = nil
    var headerCaption: String? = nil
    var roundSegmentFills: [Double]? = nil
    /// Reserves the bottom action lane so choice grids line up with module lessons.
    var reservesActionTraySpace: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lessonPortalDismiss) private var portalDismiss
    @State private var showCloseConfirm = false
    @State private var showResetConfirm = false
    private var headerHeight: CGFloat { headerCaption == nil ? 58 : 74 }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    content()
                        .padding(.bottom, reservesActionTraySpace ? LessonActionTrayLayout.reservedHeight : 0)
                        .frame(
                            width: proxy.size.width,
                            height: max(0, proxy.size.height - headerHeight),
                            alignment: .top
                        )
                        .position(
                            x: proxy.size.width / 2,
                            y: headerHeight + max(0, proxy.size.height - headerHeight) / 2
                        )

                    // Pin chrome with explicit geometry rather than sharing a flexible
                    // layout with lesson content. Do not clip content: the module
                    // feedback tray paints into the bottom safe area
                    // (`ignoresSafeArea(.bottom)`), and clipping would cut that fill and
                    // reveal the shell background as a white strip.
                    header
                        .frame(width: proxy.size.width, height: headerHeight)
                        .background(Brand.canvas)
                        .position(x: proxy.size.width / 2, y: headerHeight / 2)
                        .zIndex(100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.canvas.ignoresSafeArea())

            if showCloseConfirm {
                confirmScrim
                    .onTapGesture {
                        Haptics.tap()
                        dismissCloseConfirm()
                    }
                    .zIndex(200)

                LeaveStoneConfirmCard(
                    palette: palette,
                    paletteShadow: paletteShadow,
                    message: leaveConfirmMessage,
                    keepGoing: dismissCloseConfirm,
                    leave: confirmLeave
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(201)
            }

            if showResetConfirm {
                confirmScrim
                    .onTapGesture {
                        Haptics.tap()
                        dismissResetConfirm()
                    }
                    .zIndex(200)

                ResetStoneConfirmCard(
                    palette: palette,
                    paletteShadow: paletteShadow,
                    keepGoing: dismissResetConfirm,
                    reset: {
                        showResetConfirm = false
                        onReset?()
                    }
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(201)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: showCloseConfirm)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: showResetConfirm)
        .tint(palette)
    }

    private var confirmScrim: some View {
        StoneConfirmScrim()
    }

    private func dismissCloseConfirm() {
        showCloseConfirm = false
    }

    private func dismissResetConfirm() {
        showResetConfirm = false
    }

    private func confirmLeave() {
        showCloseConfirm = false
        onLeave?()
        portalDismiss?()
        dismiss()
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                resetButton

                if let roundSegmentFills, !roundSegmentFills.isEmpty {
                    PhaseReviewSegmentedProgressBar(
                        segmentFills: roundSegmentFills,
                        color: palette,
                        shadowColor: paletteShadow
                    )
                } else {
                    LessonProgressBar(progress: progress, color: palette, shadowColor: paletteShadow)
                }

                LessonChromeIconButton(systemName: "xmark", tint: Brand.secondaryLabel) {
                    if progress > 0 && progress < 1 {
                        showCloseConfirm = true
                    } else {
                        confirmLeave()
                    }
                }
                .opacity(showsCloseButton ? 1 : 0)
                .allowsHitTesting(showsCloseButton)
            }

            if let headerCaption {
                Text(headerCaption)
                    .font(.asl(12, weight: .medium))
                    .foregroundStyle(Brand.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, headerCaption == nil ? 14 : 10)
    }

    @ViewBuilder
    private var resetButton: some View {
        if showReset, onReset != nil {
            LessonChromeIconButton(systemName: "arrow.counterclockwise", tint: Brand.secondaryLabel) {
                showResetConfirm = true
            }
        } else {
            Color.clear
                .frame(width: 36, height: 36)
        }
    }
}

struct LessonProgressBar: View {
    let progress: Double
    let color: Color
    var shadowColor: Color? = nil

    private let barHeight: CGFloat = PremiumProgressBarMetrics.lessonBarHeight

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                PremiumProgressBarTrack(height: barHeight)
                PremiumProgressBarFill(color: color, shadowColor: shadowColor, height: barHeight)
                    .frame(width: barWidth(in: geo))
                    .clipShape(Capsule(style: .continuous))
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: progress)
            }
        }
        .frame(height: barHeight)
        .onChange(of: progress) { _, _ in
            Haptics.progressBump()
        }
    }

    private func barWidth(in geo: GeometryProxy) -> CGFloat {
        let clamped = max(0, min(1, progress))
        let width = geo.size.width * clamped
        guard width > 0 else { return 0 }
        return min(geo.size.width, max(PremiumProgressBarMetrics.minFillWidth, width))
    }
}

private struct PhaseReviewSegmentedProgressBar: View {
    let segmentFills: [Double]
    let color: Color
    var shadowColor: Color? = nil

    private let barHeight: CGFloat = PremiumProgressBarMetrics.lessonBarHeight
    private let segmentGap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: segmentGap) {
                ForEach(Array(segmentFills.enumerated()), id: \.offset) { _, fill in
                    ZStack(alignment: .leading) {
                        PremiumProgressBarTrack(height: barHeight)
                        PremiumProgressBarFill(color: color, shadowColor: shadowColor, height: barHeight)
                            .frame(width: segmentWidth(totalWidth: geo.size.width, fill: fill))
                            .clipShape(Capsule(style: .continuous))
                            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: fill)
                    }
                }
            }
        }
        .frame(height: barHeight)
    }

    private func segmentWidth(totalWidth: CGFloat, fill: Double) -> CGFloat {
        let count = max(segmentFills.count, 1)
        let gaps = segmentGap * CGFloat(max(count - 1, 0))
        let segmentTotal = max(0, totalWidth - gaps) / CGFloat(count)
        let clamped = max(0, min(1, fill))
        let width = segmentTotal * clamped
        guard width > 0 else { return 0 }
        return min(segmentTotal, max(PremiumProgressBarMetrics.minFillWidth, width))
    }
}

// MARK: - Bottom action tray (module + practice)

struct ModuleFeedback: Equatable {
    let headline: String
    let answer: String?
    let systemImage: String
    let foregroundColor: Color
}

enum ModuleNavigationButtonState: Equatable {
    case waiting(String)
    case checkAnswer
    case ready(String)
    case correct(headline: String, actionTitle: String)
    case wrong(headline: String, answer: String, actionTitle: String)

    var buttonTitle: String {
        switch self {
        case .waiting(let title), .ready(let title):
            return title
        case .checkAnswer:
            return "Check answer"
        case .correct(_, let actionTitle), .wrong(_, _, let actionTitle):
            return actionTitle
        }
    }

    var isEnabled: Bool {
        switch self {
        case .waiting:
            return false
        case .checkAnswer, .ready, .correct, .wrong:
            return true
        }
    }

    var isWaiting: Bool {
        if case .waiting = self {
            return true
        }
        return false
    }

    static var reservedTrayHeight: CGFloat { LessonActionTrayLayout.expandedReservedHeight }

    var reservedTrayHeight: CGFloat {
        LessonActionTrayLayout.reservedHeight(for: self)
    }
    static var buttonHeight: CGFloat { LessonActionTrayLayout.buttonHeight }

    var feedback: ModuleFeedback? {
        switch self {
        case .correct(let headline, _):
            return ModuleFeedback(
                headline: headline,
                answer: nil,
                systemImage: "checkmark.circle.fill",
                foregroundColor: Color.lessonCorrectText
            )
        case .wrong(let headline, let answer, _):
            return ModuleFeedback(
                headline: headline,
                answer: answer,
                systemImage: "xmark.circle.fill",
                foregroundColor: Color.lessonWrongText
            )
        case .waiting, .checkAnswer, .ready:
            return nil
        }
    }

    func panelColor(palette: Color) -> Color {
        switch self {
        case .waiting, .checkAnswer, .ready:
            return Brand.canvas
        case .correct:
            return Color.lessonCorrectPanel
        case .wrong:
            return Color.lessonErrorPanel
        }
    }

    func feedbackForegroundColor(palette: Color) -> Color {
        switch self {
        case .correct:
            return Color.lessonCorrectText
        case .wrong:
            return Color.lessonWrongText
        case .waiting, .checkAnswer, .ready:
            return Brand.textPrimary
        }
    }

    func feedbackIconColor(palette: Color) -> Color {
        switch self {
        case .correct:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        case .waiting, .checkAnswer, .ready:
            return Brand.textPrimary
        }
    }

    func buttonColor(palette: Color) -> Color {
        switch self {
        case .waiting:
            return Brand.divider.opacity(0.65)
        case .checkAnswer, .ready:
            return palette
        case .correct:
            return Color.lessonGreen
        case .wrong:
            return Color.lessonCoralButton
        }
    }

    func buttonDepthColor(paletteShadow: Color) -> Color {
        switch self {
        case .waiting:
            return Brand.divider
        case .checkAnswer, .ready:
            return paletteShadow
        case .correct:
            return Color.lessonGreenShadow
        case .wrong:
            return Color.lessonCoralButtonShadow
        }
    }
}

struct LessonActionTray: View {
    let state: ModuleNavigationButtonState
    let palette: Color
    let paletteShadow: Color
    let action: () -> Void

    var body: some View {
        let usesTintedFeedbackPanel = state.feedback != nil

        VStack(alignment: .leading, spacing: LessonActionTrayLayout.feedbackToButtonSpacing) {
            if let feedback = state.feedback {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: feedback.systemImage)
                        .font(LessonQuestionLayout.feedbackIconFont)
                        .foregroundStyle(state.feedbackIconColor(palette: palette))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feedback.headline)
                            .font(LessonQuestionLayout.feedbackHeadlineFont)
                            .foregroundStyle(state.feedbackForegroundColor(palette: palette))
                        if let answer = feedback.answer {
                            (Text("Correct answer: ")
                                .font(LessonQuestionLayout.feedbackLabelFont)
                            + Text(answer)
                                .font(LessonQuestionLayout.feedbackAnswerFont))
                                .foregroundStyle(Brand.textPrimary)
                        }
                    }
                }
            }

            PressableLessonPrimaryButton(
                title: state.buttonTitle,
                isEnabled: state.isEnabled,
                color: state.buttonColor(palette: palette),
                depthColor: state.buttonDepthColor(paletteShadow: paletteShadow),
                action: action
            )
        }
        .padding(.horizontal, LessonActionTrayLayout.horizontalPadding)
        .padding(.top, usesTintedFeedbackPanel ? LessonActionTrayLayout.feedbackPanelTopPadding : 0)
        .padding(.bottom, LessonActionTrayLayout.effectiveBottomPadding)
        .background {
            if usesTintedFeedbackPanel {
                state.panelColor(palette: palette)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Brand.canvas
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LessonActionTrayLayout.reservedHeight(for: state), alignment: .bottom)
    }
}

enum PracticeContinueCopy {
    private static let titles = ["Continue", "Next question"]

    static func nextAction(index: inout Int) -> String {
        let title = titles[index % titles.count]
        index += 1
        return title
    }
}
