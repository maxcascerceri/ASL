//
//  HomeTabView.swift
//  ASL
//

import SwiftUI
import UIKit

// MARK: - Root

struct HomeTabView: View {
    @ObservedObject var store: ASLDataStore
    var lessonEntryRevealCoordinator: LessonEntryRevealCoordinator

    var body: some View {
        NavigationStack {
            HomeFeedView(
                store: store,
                lessonEntryRevealCoordinator: lessonEntryRevealCoordinator
            )
                .toolbar(.hidden, for: .navigationBar)
                .containerBackground(Brand.homeBackground, for: .navigation)
        }
        .background(Brand.homeBackground.ignoresSafeArea())
    }
}

// MARK: - Feed

private struct HomeFeedView: View {
    @ObservedObject var store: ASLDataStore
    var lessonEntryRevealCoordinator: LessonEntryRevealCoordinator

    @State private var activeUnitIndex: Int = 0
    @State private var unitFrames: [Int: CGFloat] = [:]
    @State private var lastAutoScrolledUnitId: String?
    @State private var pendingStartUnit: ASLUnit?
    @State private var nextLessonRoute: NextLessonRoute?

    private let activationThresholdY: CGFloat = 40

    private var primaryPath: ASLPath? { store.paths.first }

    private var units: [ASLUnit] {
        guard let id = primaryPath?.id else { return [] }
        return store.unitsByPathId[id] ?? []
    }

    private var clampedActive: Int {
        guard !units.isEmpty else { return 0 }
        return max(0, min(activeUnitIndex, units.count - 1))
    }

    private var activeUnit: ASLUnit? {
        guard !units.isEmpty else { return nil }
        return units[clampedActive]
    }

    /// The unit the learner should work on next: the first unit that has not
    /// been fully completed. Drives the Continue bubble and scroll-to guidance.
    private var currentLearningUnitIndex: Int? {
        units.firstIndex { !$0.isReview && !store.isUnitComplete($0) }
    }

    /// Continue bubble on the earliest incomplete stone in the next learning
    /// unit — stone 1 when nothing has been started, stone 2 after stone 1
    /// is complete, and so on.
    private var continueBubbleLessonId: String? {
        guard let unitIndex = currentLearningUnitIndex,
              units.indices.contains(unitIndex) else { return nil }
        let unit = units[unitIndex]
        guard !unit.isReview else { return nil }
        guard !store.isUnitComplete(unit) else { return nil }

        let lessons = (store.lessonsByUnitId[unit.id] ?? [])
            .sorted(by: { $0.sortOrder < $1.sortOrder })
        guard let resumeIndex = lessons.indices.first(where: {
            store.lessonProgress(for: lessons[$0].id) < 1
        }) else {
            return nil
        }
        return lessons[resumeIndex].id
    }

    /// Initial home position: the earliest unit that still has a stone to play
    /// (same target as the Continue bubble), not the furthest unit the learner
    /// has touched elsewhere on the path.
    private var homeLandingUnitIndex: Int? {
        currentLearningUnitIndex
    }

    private var homeLandingUnitId: String? {
        guard let index = homeLandingUnitIndex, units.indices.contains(index) else { return nil }
        return units[index].id
    }

    private var unitRowModels: [HomeUnitRowModel] {
        units.enumerated().map { index, unit in
            HomeUnitRowModel(
                unit: unit,
                index: index,
                isReviewAvailable: isReviewUnitAvailable(at: index)
            )
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            HomeFeedScrollView(
                proxy: proxy,
                store: store,
                units: units,
                unitRowModels: unitRowModels,
                isLoading: units.isEmpty && (store.isLoadingPaths || store.isLoadingUnits),
                continueBubbleLessonId: continueBubbleLessonId,
                activeUnit: activeUnit,
                clampedActive: clampedActive,
                homeLandingUnitId: homeLandingUnitId,
                currentLearningUnitIndex: currentLearningUnitIndex,
                unitFrames: $unitFrames,
                nextLessonRoute: $nextLessonRoute,
                lastAutoScrolledUnitId: $lastAutoScrolledUnitId,
                pendingStartUnit: $pendingStartUnit,
                lessonEntryRevealCoordinator: lessonEntryRevealCoordinator,
                onUpdateActiveUnit: updateActiveUnit,
                onOpenPendingStart: openPendingStartUnitIfReady,
                onAutoStartUnit: startNextUnit
            )
        }
        .onChange(of: nextLessonRoute?.id) { _, _ in syncHomeUnitMedalBlocking() }
        .onChange(of: pendingStartUnit?.id) { _, _ in syncHomeUnitMedalBlocking() }
        .onChange(of: store.isLessonMediaSessionActive) { _, _ in syncHomeUnitMedalBlocking() }
        .onChange(of: store.celebratedUnit?.id) { _, _ in syncHomeUnitMedalBlocking() }
        .onChange(of: store.pendingAutoStartUnitId) { _, _ in syncHomeUnitMedalBlocking() }
        .background(Brand.homeBackground.ignoresSafeArea())
        .task {
            await store.ensureHomeCurriculumLoaded()
        }
        .task(id: continueBubbleLessonId) {
            store.preloadContinueLessonIfPossible(
                units: units,
                lessonId: continueBubbleLessonId
            )
        }
        .task(id: freeRoamMediaTaskKey) {
            guard !units.isEmpty else { return }
            store.prepareFreeRoamHomeMedia(
                units: units,
                priorityUnitIndices: prioritizedFreeRoamUnitIndices
            )
        }
        .onChange(of: clampedActive) { _, active in
            store.preloadStoneOneMediaNear(activeIndex: active, in: units, radius: 2)
        }
        .onChange(of: homeLandingUnitIndex) { _, _ in
            guard !units.isEmpty else { return }
            store.prepareFreeRoamHomeMedia(
                units: units,
                priorityUnitIndices: prioritizedFreeRoamUnitIndices
            )
        }
    }

    private var freeRoamMediaTaskKey: String {
        units.map(\.id).joined(separator: "|")
    }

    /// Units to warm first: pinned/active unit, scroll neighbors, continue target, landing unit.
    private var prioritizedFreeRoamUnitIndices: [Int] {
        guard !units.isEmpty else { return [] }

        var indices: [Int] = []
        var seen = Set<Int>()

        func append(_ index: Int?) {
            guard let index, units.indices.contains(index), seen.insert(index).inserted else { return }
            indices.append(index)
        }

        append(clampedActive)
        for offset in -2...2 where offset != 0 {
            append(clampedActive + offset)
        }
        if let continueIndex = currentLearningUnitIndex {
            append(continueIndex)
        }
        append(homeLandingUnitIndex)

        return indices
    }

    private func isReviewUnitAvailable(at index: Int) -> Bool {
        store.isReviewUnitAvailable(at: index, in: units)
    }

    private func startNextUnit(_ unit: ASLUnit) {
        if openFirstLesson(in: unit) {
            return
        }
        pendingStartUnit = unit
        store.loadLessons(for: unit)
    }

    @discardableResult
    private func openFirstLesson(in unit: ASLUnit) -> Bool {
        guard let lesson = (store.lessonsByUnitId[unit.id] ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).first else {
            return false
        }
        nextLessonRoute = NextLessonRoute(unit: unit, lesson: lesson)
        return true
    }

    private func openPendingStartUnitIfReady() {
        guard let unit = pendingStartUnit else { return }
        if openFirstLesson(in: unit) {
            pendingStartUnit = nil
        }
    }

    private func updateActiveUnit() {
        guard !unitFrames.isEmpty else { return }
        let passed = unitFrames.filter { $0.value <= activationThresholdY }
        let newIndex = passed.max(by: { $0.value < $1.value })?.key ?? 0
        if newIndex != activeUnitIndex {
            Haptics.progressBump()
            activeUnitIndex = newIndex
        }
    }

    private func syncHomeUnitMedalBlocking() {
        guard store.homeUnitFlowBlocksMedalCelebrations else { return }

        if store.isLessonMediaSessionActive {
            store.endHomeUnitFlowMedalBlocking()
            return
        }

        if pendingStartUnit != nil, nextLessonRoute == nil { return }
        if store.celebratedUnit != nil { return }

        store.endHomeUnitFlowMedalBlocking()
    }
}

private struct UnitFramesPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct NextLessonRoute: Identifiable, Hashable {
    let unit: ASLUnit
    let lesson: ASLLesson

    var id: String { lesson.id }
}

/// One-shot confetti burst over the entire home feed when the user finishes a
/// milestone unit (every 5th). Self-cleaning via `clearCelebration()`.
private struct HomeConfettiBurst: View {
    let palette: Color
    @State private var startTime: Date = .now

    private let particleCount = 80
    private let duration: Double = 1.4

    private var particles: [Particle] {
        (0..<particleCount).map { i in
            Particle(
                seed: i,
                horizontal: Double.random(in: 0...1),
                rotationSpeed: Double.random(in: -3...3),
                colorMix: Double.random(in: 0...1)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(startTime)
                guard t < duration + 0.3 else { return }
                for particle in particles {
                    let progress = min(1, max(0, (t - particle.seedDelay) / duration))
                    guard progress > 0 && progress < 1 else { continue }

                    let x = particle.horizontal * size.width + sin(progress * .pi * 4) * 18
                    let y = -20 + progress * (size.height + 80)
                    let angle = progress * .pi * 2 * particle.rotationSpeed

                    var transform = CGAffineTransform(translationX: x, y: y)
                    transform = transform.rotated(by: angle)

                    let rect = CGRect(x: -4, y: -8, width: 8, height: 14)
                    let path = Path(roundedRect: rect, cornerRadius: 2).applying(transform)
                    ctx.fill(path, with: .color(particleColor(particle.colorMix)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startTime = .now }
    }

    private func particleColor(_ mix: Double) -> Color {
        if mix < 0.33 { return palette }
        if mix < 0.66 { return Color.lessonGreen }
        return Color.yellow
    }

    private struct Particle {
        let seed: Int
        let horizontal: Double
        let rotationSpeed: Double
        let colorMix: Double
        var seedDelay: Double { Double(seed) * 0.012 }
    }
}

// MARK: - Pinned Header

private enum HomePinnedChrome {
    /// Inset from screen edges for the stats row.
    static let sideInset: CGFloat = 40
    /// Extra inset for the pinned unit card so it reads slightly narrower than the stats row.
    static let unitCardSideInset: CGFloat = 42
    static let statIconSize: CGFloat = 21
    static let statChipSpacing: CGFloat = 8
    static let statGroupSpacing: CGFloat = 42
    static let unitSymbolSize: CGFloat = 20
    static let unitSymbolFrame: CGFloat = 42
    static let unitInnerPaddingH: CGFloat = 14
    /// Extra space between the pinned Unit 1 card and the first stone row (no scroll-path pill on Getting Started).
    static let firstUnitPathTopInset: CGFloat = 40
    static let defaultUnitPathTopInset: CGFloat = 8
}

private struct PinnedHeader: View {
    let activeUnit: ASLUnit?
    let activeUnitIndex: Int
    let palette: UnitPalette
    @ObservedObject var store: ASLDataStore

    var body: some View {
        VStack(spacing: 14) {
            HomeStatsBar(
                stars: store.totalStars,
                streak: store.dailyActivityStreak,
                signsLearned: store.learnedSignsCount
            )
                .padding(.horizontal, HomePinnedChrome.sideInset)
                .padding(.top, 8)

            if let activeUnit {
                UnitHeaderCard(
                    unitNumber: activeUnit.isReview ? nil : activeUnitIndex + 1,
                    title: activeUnit.isReview
                        ? (activeUnit.phaseTitle ?? activeUnit.title)
                        : activeUnit.title,
                    subtitle: activeUnit.isReview
                        ? ASLPhaseReviewCopy.checkpointLabel(for: activeUnit.phaseKey)
                        : nil,
                    palette: palette
                )
                .animation(.easeOut(duration: 0.22), value: activeUnitIndex)
                .padding(.horizontal, HomePinnedChrome.unitCardSideInset)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 12)
        .background {
            Brand.homeBackground
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Stats Bar

private struct HomeStatsForegroundKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var homeStatsForeground: Bool {
        get { self[HomeStatsForegroundKey.self] }
        set { self[HomeStatsForegroundKey.self] = newValue }
    }
}

private struct HomeStatsBar: View {
    let stars: Int
    let streak: Int
    /// Signs learned on the path and in the dictionary.
    let signsLearned: Int

    @Environment(\.homeStatsForeground) private var isForeground

    @State private var displayedStars: Int?
    @State private var displayedStreak: Int?
    @State private var displayedSignsLearned: Int?
    @State private var didSeedDisplay = false

    /// Resolved once — see `ASLIconSymbol.signsLearned`.
    private static let signsLearnedIconName = ASLIconSymbol.signsLearned

    var body: some View {
        HStack(spacing: HomePinnedChrome.statGroupSpacing) {
            stat(icon: "flame.fill", tint: .orange, target: streak, displayed: displayedStreak)
            stat(icon: "star.fill", tint: .yellow, target: stars, displayed: displayedStars)
            signsStat(tint: Brand.primary, target: signsLearned, displayed: displayedSignsLearned)
        }
        .frame(maxWidth: .infinity)
        .font(.asl(ASLTextMetrics.size(for: .progressStat, variant: .compact), weight: .semibold))
        .onAppear { seedDisplayedValuesIfNeeded() }
        .onChange(of: isForeground) { _, foreground in
            guard foreground else { return }
            catchUpDisplayedStats(animated: true)
        }
        .onChange(of: stars) { _, _ in
            guard isForeground else { return }
            catchUpDisplayedStats(animated: true)
        }
        .onChange(of: streak) { _, _ in
            guard isForeground else { return }
            catchUpDisplayedStats(animated: true)
        }
        .onChange(of: signsLearned) { _, _ in
            guard isForeground else { return }
            catchUpDisplayedStats(animated: true)
        }
    }

    private func stat(icon: String, tint: Color, target: Int, displayed: Int?) -> some View {
        let shown = displayed ?? target
        return HStack(spacing: HomePinnedChrome.statChipSpacing) {
            ASLIcon(
                source: .symbol(icon),
                role: .metric,
                tint: tint,
                bounceTrigger: shown
            )
            Text("\(shown)")
                .foregroundStyle(Brand.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shown)))
                .animation(ASLIconMotion.valueChange, value: shown)
        }
    }

    private func signsStat(tint: Color, target: Int, displayed: Int?) -> some View {
        let shown = displayed ?? target
        return HStack(spacing: HomePinnedChrome.statChipSpacing) {
            ASLIcon(
                source: .symbol(Self.signsLearnedIconName),
                role: .metric,
                tint: tint,
                bounceTrigger: shown
            )
            Text("\(shown)")
                .foregroundStyle(Brand.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shown)))
                .animation(ASLIconMotion.valueChange, value: shown)
        }
    }

    private func seedDisplayedValuesIfNeeded() {
        guard !didSeedDisplay else { return }
        didSeedDisplay = true
        displayedStars = stars
        displayedStreak = streak
        displayedSignsLearned = signsLearned
    }

    private func catchUpDisplayedStats(animated: Bool) {
        let apply = {
            if displayedStars != stars { displayedStars = stars }
            if displayedStreak != streak { displayedStreak = streak }
            if displayedSignsLearned != signsLearned { displayedSignsLearned = signsLearned }
        }
        if animated {
            withAnimation(ASLIconMotion.valueChange, apply)
        } else {
            apply()
        }
    }
}

// MARK: - Section Dividers

/// Compact raised label above each unit on the scroll path (pinned header shows the full card).
private struct UnitDivider: View {
    let title: String
    let palette: UnitPalette

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Brand.divider)
                .frame(height: 1)
            Text(title)
                .font(.asl(18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(PremiumCardStyle.softDepth(for: palette.color, hint: palette.shadow))
                            .offset(y: RaisedCardMetrics.depth)
                        Capsule(style: .continuous)
                            .fill(palette.color)
                    }
                }
                .elevation(.sectionPill(tint: palette.shadow))
                .padding(.bottom, RaisedCardMetrics.depth)
                .fixedSize()
            Rectangle()
                .fill(Brand.divider)
                .frame(height: 1)
        }
    }
}

// MARK: - Home load error

private struct HomeUnitLessonsRetryRow: View {
    let unitTitle: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Stones didn’t load for \(unitTitle)")
                .font(.asl(14, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)

            Button {
                Haptics.tap()
                onRetry()
            } label: {
                Text("Retry")
                    .aslStyle(.cardDescription, variant: .prominent, color: Brand.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
    }
}

private struct HomeCurriculumErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)

            Text("Path didn’t load")
                .aslStyle(.cardTitle, variant: .compact)

            Text(message)
                .font(.asl(15, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                onRetry()
            } label: {
                Text("Try Again")
                    .aslStyle(.cardDescription, variant: .prominent, color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Brand.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feed scroll surface

private struct HomeUnitRowModel: Identifiable {
    let unit: ASLUnit
    let index: Int
    let isReviewAvailable: Bool

    var id: String { unit.id }
}

private struct HomeFeedScrollView: View {
    let proxy: ScrollViewProxy
    @ObservedObject var store: ASLDataStore
    let units: [ASLUnit]
    let unitRowModels: [HomeUnitRowModel]
    let isLoading: Bool
    let continueBubbleLessonId: String?
    let activeUnit: ASLUnit?
    let clampedActive: Int
    let homeLandingUnitId: String?
    let currentLearningUnitIndex: Int?
    @Binding var unitFrames: [Int: CGFloat]
    @Binding var nextLessonRoute: NextLessonRoute?
    @Binding var lastAutoScrolledUnitId: String?
    @Binding var pendingStartUnit: ASLUnit?
    var lessonEntryRevealCoordinator: LessonEntryRevealCoordinator
    let onUpdateActiveUnit: () -> Void
    let onOpenPendingStart: () -> Void
    let onAutoStartUnit: (ASLUnit) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        homeFeedContent
            .navigationDestination(item: $nextLessonRoute, destination: lessonDestination)
            .task(id: homeLandingUnitId) {
                await scrollToHomeLandingUnitIfNeeded()
            }
            .task(id: store.paths.first?.id) {
                if let path = store.paths.first, store.unitsByPathId[path.id] == nil {
                    store.loadUnits(for: path)
                }
            }
            .onChange(of: store.practiceDailyEngine.navigation.consumeHomePath) { _, shouldScroll in
                guard shouldScroll else { return }
                store.practiceDailyEngine.navigation.acknowledgeHomePathConsumed()
                scrollToCurrentLearningUnit()
            }
            .background(HomeScrollSurfaceBackground().ignoresSafeArea())
    }

    private var homeFeedContent: some View {
        scrollView
            .scrollContentBackground(.hidden)
            .coordinateSpace(.named("homeScroll"))
            .onAppear {
                store.refreshDailyStreakIfNeeded()
                configureLessonEntryReveal()
            }
            .onPreferenceChange(UnitFramesPreferenceKey.self) { frames in
                handleFrameChange(frames)
            }
            .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader }
            .overlay(alignment: .bottomTrailing) { scrollToTopButton }
            .overlay { confettiOverlay }
            .onChange(of: store.celebratedUnit?.id) { _, newId in
                handleCelebrationChange(newId)
            }
            .onChange(of: nextLessonRoute?.id) { _, newId in
                handleLessonRouteCleared(newId)
            }
            .onChange(of: store.pendingAutoStartUnitId) { _, _ in
                consumeAutoStartHandoffIfNeeded()
            }
            .onChange(of: store.lessonsByUnitId) { _, _ in onOpenPendingStart() }
    }

    @ViewBuilder
    private func lessonDestination(route: NextLessonRoute) -> some View {
        LessonRouter(lesson: route.lesson, unit: route.unit, store: store)
            .environment(\.lessonPortalDismiss) {
                dismissActiveLessonRoute()
            }
            .transaction { $0.disablesAnimations = true }
    }

    private func dismissActiveLessonRoute() {
        PortalNavigation.withoutStackAnimation {
            nextLessonRoute = nil
        }
        lessonEntryRevealCoordinator.cancel()
    }

    private func handleLessonRouteCleared(_ newId: String?) {
        if newId == nil {
            lessonEntryRevealCoordinator.cancel()
            consumeAutoStartHandoffIfNeeded()
        }
    }

    private func consumeAutoStartHandoffIfNeeded() {
        guard nextLessonRoute == nil,
              let unitId = store.pendingAutoStartUnitId,
              let unit = units.first(where: { $0.id == unitId }) else { return }
        store.clearPendingAutoStartUnit()
        pendingStartUnit = unit
        onAutoStartUnit(unit)
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(unit.id, anchor: .top)
        }
    }

    private var scrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 60)
                } else if unitRowModels.isEmpty, let message = store.homeLoadErrorMessage {
                    HomeCurriculumErrorState(message: message) {
                        store.reloadHomeCurriculum()
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 48)
                }
                ForEach(unitRowModels) { row in
                    HomeUnitPathRow(
                        model: row,
                        continueBubbleLessonId: continueBubbleLessonId,
                        store: store,
                        onRequestLessonEntry: requestLessonEntry,
                        onModulePreviewDismissed: handleModulePreviewDismissed
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .background(HomeScrollSurfaceBackground())
    }

    private var pinnedHeader: some View {
        PinnedHeader(
            activeUnit: activeUnit,
            activeUnitIndex: clampedActive,
            palette: UnitPalette.palette(for: clampedActive),
            store: store
        )
        .zIndex(10)
    }

    @ViewBuilder
    private var scrollToTopButton: some View {
        if clampedActive > 0, let firstID = units.first?.id {
            ScrollToTopButton(palette: UnitPalette.palette(for: 0)) {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 28)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var confettiOverlay: some View {
        if let celebrated = store.celebratedUnit {
            let paletteColor = UnitPalette.palette(for: max(0, celebrated.sortOrder - 1)).color
            if shouldUseFullConfetti(celebrated) {
                HomeConfettiBurst(palette: paletteColor)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            } else if !reduceMotion {
                ConfettiCanvas(palette: paletteColor, style: .subtleStreak)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    private func shouldUseFullConfetti(_ unit: ASLUnit) -> Bool {
        if unit.isReview, ASLPhaseReviewCopy.isMilestone(phaseKey: unit.phaseKey) {
            return true
        }
        return unit.sortOrder.isMultiple(of: 5)
    }

    private func handleFrameChange(_ frames: [Int: CGFloat]) {
        guard frames != unitFrames else { return }
        unitFrames = frames
        onUpdateActiveUnit()
    }

    private func configureLessonEntryReveal() {
        lessonEntryRevealCoordinator.onCommitNavigation = { request in
            PortalNavigation.withoutStackAnimation {
                nextLessonRoute = NextLessonRoute(unit: request.unit, lesson: request.lesson)
            }
        }
        lessonEntryRevealCoordinator.onDismissNavigation = {
            dismissActiveLessonRoute()
        }
    }

    private func requestLessonEntry(_ request: LessonEntryRevealRequest) {
        lessonEntryRevealCoordinator.begin(request: request, reduceMotion: reduceMotion)
    }

    private func handleModulePreviewDismissed() {
        lessonEntryRevealCoordinator.sheetDidDismiss(reduceMotion: reduceMotion)
    }

    private func handleCelebrationChange(_ newId: String?) {
        guard newId != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            store.clearCelebration()
        }
    }

    private func scrollToCurrentLearningUnit() {
        let targetId: String? = {
            if let index = currentLearningUnitIndex, units.indices.contains(index) {
                return units[index].id
            }
            return homeLandingUnitId
        }()
        guard let targetId else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(targetId, anchor: .top)
        }
    }

    private func scrollToHomeLandingUnitIfNeeded() async {
        guard let unitId = homeLandingUnitId,
              let index = units.firstIndex(where: { $0.id == unitId })
        else { return }
        guard unitId != lastAutoScrolledUnitId else { return }
        lastAutoScrolledUnitId = unitId
        guard index > 0 else { return }

        try? await Task.sleep(nanoseconds: 150_000_000)
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(unitId, anchor: .top)
        }
    }
}

// MARK: - Unit path row

private struct HomeUnitPathRow: View {
    let model: HomeUnitRowModel
    let continueBubbleLessonId: String?
    @ObservedObject var store: ASLDataStore
    let onRequestLessonEntry: (LessonEntryRevealRequest) -> Void
    let onModulePreviewDismissed: () -> Void

    var body: some View {
        UnitPathSection(
            unit: model.unit,
            index: model.index,
            palette: UnitPalette.palette(for: model.index),
            isReviewAvailable: model.isReviewAvailable,
            continueBubbleLessonId: continueBubbleLessonId,
            store: store,
            onRequestLessonEntry: onRequestLessonEntry,
            onModulePreviewDismissed: onModulePreviewDismissed
        )
        .id(model.unit.id)
        .padding(
            .top,
            model.index == 0
                ? HomePinnedChrome.firstUnitPathTopInset
                : HomePinnedChrome.defaultUnitPathTopInset
        )
        .padding(.bottom, model.unit.isReview ? 28 : 22)
    }
}

// MARK: - Unit Path Section (phase + unit strip scroll with path; pinned card mirrors active unit)

private struct UnitPathSection: View {
    let unit: ASLUnit
    let index: Int
    let palette: UnitPalette
    let isReviewAvailable: Bool
    let continueBubbleLessonId: String?
    @ObservedObject var store: ASLDataStore
    let onRequestLessonEntry: (LessonEntryRevealRequest) -> Void
    let onModulePreviewDismissed: () -> Void

    private var lessons: [ASLLesson] {
        store.lessonsByUnitId[unit.id] ?? []
    }

    /// First unit uses the pinned header only — no scroll-path pill + divider lines.
    private var showsPathUnitLabel: Bool {
        unit.title != "Getting Started" && unit.title != "Greetings" && unit.title != "First Signs"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if unit.isReview {
                phaseReviewSection
            } else {
                if showsPathUnitLabel {
                    UnitDivider(
                        title: unit.title,
                        palette: palette
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }

                if lessons.isEmpty && store.isLoadingLessons(for: unit.id) {
                    ProgressView().padding(.vertical, 24)
                } else if lessons.isEmpty && store.didFailToLoadLessons(for: unit.id) {
                    HomeUnitLessonsRetryRow(unitTitle: unit.title) {
                        store.loadLessons(for: unit)
                    }
                } else {
                    LessonPathView(
                        lessons: lessons,
                        palette: palette,
                        continueBubbleLessonId: continueBubbleLessonId,
                        unitIndex: index,
                        unit: unit,
                        store: store,
                        onRequestLessonEntry: onRequestLessonEntry,
                        onModulePreviewDismissed: onModulePreviewDismissed
                    )
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: UnitFramesPreferenceKey.self,
                        value: [index: geo.frame(in: .named("homeScroll")).minY]
                    )
            }
        )
        .task(id: unit.id) {
            if lessons.isEmpty {
                store.loadLessons(for: unit)
            } else if shouldPreloadMedia {
                store.preloadMedia(for: unit)
            }
        }
        .onChange(of: lessons.count) { _, count in
            guard count > 0, shouldPreloadMedia else { return }
            store.preloadMedia(for: unit)
        }
    }

    private var shouldPreloadMedia: Bool {
        if unit.isReview {
            return isReviewAvailable && !store.isUnitComplete(unit)
        }
        return store.hasStartedUnit(unit)
    }

    @ViewBuilder
    private var phaseReviewSection: some View {
        if let reviewLesson = lessons.first {
            ReviewCheckpointNode(
                lesson: reviewLesson,
                unit: unit,
                palette: palette,
                state: phaseReviewState,
                store: store,
                onRequestLessonEntry: onRequestLessonEntry,
                onModulePreviewDismissed: onModulePreviewDismissed
            )
            .padding(.horizontal, HomePinnedChrome.unitCardSideInset)
            .padding(.top, 8)
            .padding(.bottom, 8)
        } else if store.isLoadingLessons(for: unit.id) {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        }
    }

    private var phaseReviewState: HomeLessonNodeState {
        if store.isUnitComplete(unit) {
            return .completed
        }
        return isReviewAvailable ? .current : .locked
    }
}


// MARK: - Lesson Path

private struct LessonPathView: View {
    let lessons: [ASLLesson]
    let palette: UnitPalette
    let continueBubbleLessonId: String?
    let unitIndex: Int
    let unit: ASLUnit
    @ObservedObject var store: ASLDataStore
    let onRequestLessonEntry: (LessonEntryRevealRequest) -> Void
    let onModulePreviewDismissed: () -> Void

    /// Symmetric pattern (pixels). Multiplied by the unit's snake direction so
    /// adjacent units curve to opposite sides — the steps actually snake down
    /// the feed instead of always curving the same way.
    private let pathOffsets: [CGFloat] = [0, 75, 115, 75, 0, -75, -115, -75]
    private let stoneRowHeight: CGFloat = 100
    private let stoneRowSpacing: CGFloat = 32
    private static let pathEdgeInset: CGFloat = 22

    private static func pathVerticalNudge(for imageName: String) -> CGFloat {
        UnitMascot.homeVerticalNudge(for: imageName)
    }

    private var isFirstSignsUnit: Bool { unit.id == "p1-u01" }

    var body: some View {
        ZStack(alignment: .top) {
            stonePathStack
                .padding(.horizontal, 12)

            unitMascotOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isFirstSignsUnit, let firstLesson = lessons.first {
                row(forIndex: 0, lesson: firstLesson)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var stonePathStack: some View {
        VStack(spacing: stoneRowSpacing) {
            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                if isFirstSignsUnit, index == 0 {
                    Color.clear
                        .frame(height: stoneRowHeight)
                } else {
                    row(forIndex: index, lesson: lesson)
                }
            }
        }
    }

    private var mascotSide: MascotSide {
        unitIndex.isMultiple(of: 2) ? .leading : .trailing
    }

    /// Vertical center of the gap between lesson rows 1 and 2 (stones 2 and 3).
    private var mascotCenterY: CGFloat {
        let count = CGFloat(lessons.count)
        guard count > 0 else { return 0 }
        return (count * stoneRowHeight + max(count - 1, 0) * stoneRowSpacing) / 2
    }

    @ViewBuilder
    private var unitMascotOverlay: some View {
        if lessons.count >= 2, let imageName = UnitMascot.imageName(for: unit) {
            let mascotSize = UnitMascot.displaySize(for: imageName)
            let contentScale = UnitMascot.homePathContentScale(for: imageName)
            let topInset = mascotCenterY - mascotSize / 2 + Self.pathVerticalNudge(for: imageName)
            mascotOverlayContent(
                mascotSize: mascotSize,
                topInset: topInset,
                horizontalNudge: UnitMascot.homeHorizontalNudge(for: imageName)
            ) {
                Group {
                    if let videoResource = UnitMascot.animatedVideoResource(for: unit) {
                        UnitMascotVideoView(
                            resourceName: videoResource,
                            fallbackImageName: imageName,
                            size: mascotSize,
                            introSlot: .homeFirstSigns
                        )
                    } else {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: mascotSize, height: mascotSize)
                    }
                }
                .scaleEffect(contentScale)
            }
        }
    }

    private func mascotOverlayContent<Content: View>(
        mascotSize: CGFloat,
        topInset: CGFloat,
        horizontalNudge: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topInset)
            HStack(spacing: 0) {
                if mascotSide == .trailing { Spacer(minLength: 0) }
                content()
                    .offset(x: horizontalNudge)
                    .padding(mascotSide == .leading ? .leading : .trailing, Self.pathEdgeInset)
                if mascotSide == .leading { Spacer(minLength: 0) }
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func offset(for index: Int) -> CGFloat {
        let base = pathOffsets[index % pathOffsets.count]
        let direction: CGFloat = (unitIndex % 2 == 0) ? 1 : -1
        return base * direction
    }

    @ViewBuilder
    private func row(forIndex index: Int, lesson: ASLLesson) -> some View {
        let xOffset = offset(for: index)

        LessonNodeView(
            lesson: lesson,
            unit: unit,
            palette: palette,
            state: state(for: index),
            isFirstStone: index == 0,
            isLastStone: index == lessons.count - 1,
            lessonCount: lessons.count,
            continueBubbleLabel: continueBubbleLabel(for: index),
            store: store,
            onRequestLessonEntry: onRequestLessonEntry,
            onModulePreviewDismissed: onModulePreviewDismissed
        )
        .offset(x: xOffset)
        .frame(maxWidth: .infinity)
        // Staggered fill when the unit transitions to completed: each
        // stone settles 200ms after the previous one (left-to-right).
        .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.2),
                   value: store.completedUnitIds)
        .frame(height: stoneRowHeight)
    }

    /// Sequential stone unlock: stone 1 always playable; later stones need the prior lesson complete.
    private func state(for index: Int) -> HomeLessonNodeState {
        store.lessonNodeState(at: index, in: lessons, unit: unit)
    }

    /// Label for the floating bubble on the resume stone in the next learning
    /// unit (`HomeFeedView.continueBubbleLessonId`).
    private func continueBubbleLabel(for index: Int) -> String? {
        guard let targetId = continueBubbleLessonId else { return nil }
        guard lessons[index].id == targetId else { return nil }
        let lesson = lessons[index]
        if index == 0, store.lessonProgress(for: lesson.id) <= 0 {
            return "Start here!"
        }
        if index == lessons.count - 1 {
            return "Finish unit"
        }
        return "Continue"
    }
}

// MARK: - Lesson Node

/// Stone + module preview sheet share the same SF Symbol per lesson.
private enum LessonStoneGlyph {
    static func symbol(for lesson: ASLLesson, unit: ASLUnit, lessonCount: Int) -> String {
        switch lesson.type {
        case .module:
            return moduleSymbol(for: lesson, unit: unit, lessonCount: lessonCount)
        case .watchPick2: return "eye.fill"
        case .watchPick4: return "square.grid.2x2.fill"
        case .fillGap: return "text.alignleft"
        case .speed: return "bolt.fill"
        case .checkpoint: return "crown.fill"
        case .unknown: return "sparkles"
        }
    }

    private static func moduleSymbol(for lesson: ASLLesson, unit: ASLUnit, lessonCount: Int) -> String {
        let pools = [
            ["book.fill", "sparkles", "lightbulb.fill", "hand.wave.fill"],
            ["eye.fill", "viewfinder", "scope", "checkmark.seal.fill"],
            ["text.bubble.fill", "quote.bubble.fill", "doc.text.fill", "pencil.and.outline"],
            ["crown.fill", "flame.fill", "trophy.fill", "star.fill", "bolt.fill"],
        ]
        let isCapstone = lesson.sortOrder >= lessonCount
        let poolIndex = isCapstone ? 3 : max(0, min(lesson.sortOrder - 1, pools.count - 2))
        let pool = pools[poolIndex]
        let symbolIndex = (unit.sortOrder + lesson.sortOrder) % pool.count
        return pool[symbolIndex]
    }
}

private struct ReviewCheckpointNode: View {
    let lesson: ASLLesson
    let unit: ASLUnit
    let palette: UnitPalette
    let state: HomeLessonNodeState
    @ObservedObject var store: ASLDataStore
    let onRequestLessonEntry: (LessonEntryRevealRequest) -> Void
    let onModulePreviewDismissed: () -> Void

    @State private var showModulePreview = false

    var body: some View {
        Group {
            switch state {
            case .locked:
                plaque(isPressed: false)
            case .completed, .current:
                PressableStoneButton {
                    Haptics.tap()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        showModulePreview = true
                    }
                } label: { isPressed in
                    plaque(isPressed: isPressed)
                }
            }
        }
        .sheet(isPresented: $showModulePreview, onDismiss: onModulePreviewDismissed) {
            ModulePreviewSheet(
                lesson: lesson,
                unit: unit,
                palette: palette,
                store: store,
                onClose: {
                    showModulePreview = false
                },
                onContinue: { request in
                    onRequestLessonEntry(request)
                    showModulePreview = false
                }
            )
            .presentationDetents([.height(ModulePreviewSheetMetrics.height)])
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Brand.chrome.ignoresSafeArea()
            }
        }
    }

    private func plaque(isPressed: Bool) -> some View {
        ReviewCheckpointPlaque(
            phaseTitle: unit.phaseTitle ?? unit.title,
            phaseKey: unit.phaseKey,
            palette: palette,
            isComplete: state == .completed,
            isPressed: isPressed
        )
    }
}

private struct ReviewCheckpointPlaque: View {
    let phaseTitle: String
    let phaseKey: String?
    let palette: UnitPalette
    let isComplete: Bool
    let isPressed: Bool

    private let plaqueCornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusMedium
    private let iconSize: CGFloat = 42

    private var plaqueIcon: String {
        if isComplete { return "checkmark.seal.fill" }
        return "flag.checkered.2.crossed"
    }

    var body: some View {
        PremiumColoredCard(
            fill: palette.color,
            depthHint: palette.shadow,
            cornerRadius: plaqueCornerRadius,
            isPressed: isPressed
        ) {
            plaqueContent
        }
    }

    private var plaqueContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: iconSize, height: iconSize)
                Image(systemName: plaqueIcon)
                    .aslIconStyle(role: .unitBadge, tint: palette.color)
            }
            .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.asl(18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(ASLPhaseReviewCopy.checkpointLabel(for: phaseKey))
                    .font(.asl(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.asl(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, HomePinnedChrome.unitInnerPaddingH)
        .padding(.vertical, 18)
    }
}

// MARK: - Lesson stone chrome

private struct LessonStoneElevationModifier: ViewModifier {
    let palette: UnitPalette
    let state: HomeLessonNodeState
    let isPressed: Bool

    func body(content: Content) -> some View {
        content.elevation(.lessonStone(
            state: elevationState,
            tint: palette.color,
            isPressed: isPressed
        ))
    }

    private var elevationState: Elevation.StoneState {
        switch state {
        case .locked: return .locked
        case .current: return .current
        case .completed: return .completed
        }
    }
}

private struct LessonStoneIdleBreathModifier: ViewModifier {
    let isActive: Bool
    @State private var inhale = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && inhale ? 1.006 : 1)
            .animation(
                isActive
                    ? .easeInOut(duration: 3.1).repeatForever(autoreverses: true)
                    : .default,
                value: inhale
            )
            .onAppear {
                guard isActive else { return }
                inhale = true
            }
            .onChange(of: isActive) { _, active in
                inhale = active
            }
    }
}

private extension View {
    func lessonStoneElevation(
        palette: UnitPalette,
        state: HomeLessonNodeState,
        isPressed: Bool
    ) -> some View {
        modifier(LessonStoneElevationModifier(
            palette: palette,
            state: state,
            isPressed: isPressed
        ))
    }

    func lessonStoneIdleBreath(isActive: Bool) -> some View {
        modifier(LessonStoneIdleBreathModifier(isActive: isActive))
    }
}

private struct LessonNodeView: View {
    let lesson: ASLLesson
    let unit: ASLUnit
    let palette: UnitPalette
    let state: HomeLessonNodeState
    var isFirstStone: Bool = false
    var isLastStone: Bool = false
    var lessonCount: Int = 3
    /// Optional text shown in the floating bubble above this stone (e.g.
    /// "Continue" or "Almost Done"). Nil hides the bubble entirely.
    let continueBubbleLabel: String?
    @ObservedObject var store: ASLDataStore
    let onRequestLessonEntry: (LessonEntryRevealRequest) -> Void
    let onModulePreviewDismissed: () -> Void

    @State private var showModulePreview = false

    private let discWidth: CGFloat = PremiumLessonNodeMetrics.width
    private let discHeight: CGFloat = PremiumLessonNodeMetrics.height
    private let depth: CGFloat = PremiumLessonNodeMetrics.depth

    var body: some View {
        nodeButton
    }

    @ViewBuilder
    private var nodeButton: some View {
        switch state {
        case .locked:
            nodeStack(isPressed: false)
        case .completed, .current:
            PressableStoneButton {
                Haptics.tap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    showModulePreview = true
                }
            } label: { isPressed in
                nodeStack(isPressed: isPressed)
            }
            .sheet(isPresented: $showModulePreview, onDismiss: onModulePreviewDismissed) {
                ModulePreviewSheet(
                    lesson: lesson,
                    unit: unit,
                    palette: palette,
                    store: store,
                    onClose: {
                        showModulePreview = false
                    },
                    onContinue: { request in
                        onRequestLessonEntry(request)
                        showModulePreview = false
                    }
                )
                .presentationDetents([.height(ModulePreviewSheetMetrics.height)])
                .presentationDragIndicator(.hidden)
                .presentationBackground {
                    Brand.chrome.ignoresSafeArea()
                }
            }
        }
    }

    private func nodeStack(isPressed: Bool) -> some View {
        nodeDisc(isPressed: isPressed)
            .lessonStoneIdleBreath(isActive: state == .current && !isFirstStone && !isPressed)
            // Float the continue bubble above the stone via overlay so it
            // doesn't add height to the row — that keeps the spacing between
            // every stone identical regardless of which one is "current".
            .overlay(alignment: .top) {
                if let label = continueBubbleLabel {
                    ContinueBubble(label: label, tint: palette.color)
                        .fixedSize()
                        .offset(y: isPressed ? -24 : -32)
                        .allowsHitTesting(false)
                }
            }
            .animation(pressAnimation(isPressed: isPressed), value: isPressed)
    }

    private func nodeDisc(isPressed: Bool) -> some View {
        stoneBody(isPressed: isPressed)
        .frame(width: discWidth, height: discHeight + depth, alignment: .top)
        .scaleEffect(isPressed ? 0.966 : 1.0)
        .lessonStoneElevation(palette: palette, state: stoneElevationState, isPressed: isPressed)
        .animation(pressAnimation(isPressed: isPressed), value: isPressed)
        .animation(.easeOut(duration: 0.45), value: state)
        .animation(.easeOut(duration: 0.45), value: stoneProgress)
    }

    private func stoneBody(isPressed: Bool) -> some View {
        PremiumLessonNode(
            faceColor: faceColor,
            rimColor: rimColor,
            strokeColor: faceStrokeColor,
            isPressed: isPressed
        ) {
            glyphContent
        }
    }

    private var stoneElevationState: HomeLessonNodeState {
        if isFirstStone && state == .current { return .completed }
        return state
    }

    private var faceStrokeColor: Color {
        switch state {
        case .completed: return palette.shadow.opacity(0.28)
        case .current:
            return isFirstStone
                ? palette.shadow.opacity(0.28)
                : palette.shadow.opacity(0.18)
        case .locked: return Color.black.opacity(0.06)
        }
    }

    private func pressAnimation(isPressed: Bool) -> Animation {
        isPressed
            ? .easeOut(duration: 0.07)
            : .spring(response: 0.32, dampingFraction: 0.68)
    }

    private var stoneProgress: Double {
        if state == .completed { return 1 }
        return store.lessonProgress(for: lesson.id)
    }

    @ViewBuilder
    private var glyphContent: some View {
        ASLIcon(
            source: .symbol(glyphSymbol),
            role: .lessonStone,
            tint: glyphColor,
            isEmphasis: state != .locked
        )
        .scaleEffect(glyphScale)
        .shadow(color: glyphDepthColor, radius: 0, x: 0, y: 1)
    }

    private var glyphScale: CGFloat {
        switch state {
        case .completed, .current: return 1
        case .locked: return 0.94
        }
    }

    private var glyphDepthColor: Color {
        switch state {
        case .completed: return palette.shadow.opacity(0.42)
        case .current:
            return isFirstStone
                ? palette.shadow.opacity(0.42)
                : palette.shadow.opacity(0.28)
        case .locked: return Color.clear
        }
    }

    private var glyphSymbol: String {
        LessonStoneGlyph.symbol(for: lesson, unit: unit, lessonCount: lessonCount)
    }

    private var faceColor: Color {
        switch state {
        case .completed: return palette.color
        case .current:
            if isFirstStone { return palette.color }
            return Color.mixStone(
                base: Color(red: 0.93, green: 0.93, blue: 0.95),
                fill: palette.color,
                progress: stoneProgress
            )
        case .locked:
            return Color(red: 0.90, green: 0.91, blue: 0.94)
        }
    }

    private var rimColor: Color {
        let softShadow = PremiumCardStyle.lessonStoneDepth(for: palette.color, hint: palette.shadow)
        switch state {
        case .completed: return softShadow
        case .current:
            if isFirstStone { return softShadow }
            return Color.mixStone(
                base: PremiumCardStyle.softDepth(for: Color(red: 0.90, green: 0.91, blue: 0.94), hint: Brand.divider, mix: 0.30),
                fill: softShadow,
                progress: stoneProgress
            )
        case .locked:
            return PremiumCardStyle.softDepth(for: Color(red: 0.90, green: 0.91, blue: 0.94), hint: Brand.divider, mix: 0.30)
        }
    }

    private var glyphColor: Color {
        switch state {
        case .completed: return .white
        case .current:
            if isFirstStone { return .white }
            return stoneProgress > 0.3 ? .white : Color.white.opacity(0.92)
        case .locked:
            return Color.white.opacity(0.55)
        }
    }
}

// MARK: - Continue Bubble

private struct ContinueBubble: View {
    let label: String
    let tint: Color

    @State private var pulse = false
    @State private var activeCorner = 0
    @State private var sparkleScale: CGFloat = 0
    @State private var sparkleTimer: Timer?

    private let sparkleSymbol = "star.fill"
    private let sparkleCycleSeconds: TimeInterval = 1.5
    private let sparkleGrow = Animation.easeOut(duration: 0.18)
    private let sparkleShrink = Animation.easeIn(duration: 0.15)
    private let sparkleSpinPeriod: TimeInterval = 1.1
    private let sparkleMaxScale: CGFloat = 1
    private let labelCornerRadius: CGFloat = 10
    private let sparkleCornerInset: CGFloat = 8

    var body: some View {
        bubbleContent
            .scaleEffect(pulse ? 1.03 : 1.0)
            .subtleVerticalBob(amplitude: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
                withAnimation(sparkleGrow) {
                    sparkleScale = sparkleMaxScale
                }
                sparkleTimer?.invalidate()
                sparkleTimer = Timer.scheduledTimer(
                    withTimeInterval: sparkleCycleSeconds / 2,
                    repeats: true
                ) { _ in
                    advanceSparkle()
                }
            }
            .onDisappear {
                sparkleTimer?.invalidate()
                sparkleTimer = nil
            }
    }

    private var bubbleContent: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.asl(16, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: labelCornerRadius, style: .continuous)
                        .fill(Brand.chrome)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: labelCornerRadius, style: .continuous)
                        .strokeBorder(Brand.divider, lineWidth: 1.5)
                )
                .overlay { sparkleLayer }
            BubbleTail()
                .fill(Brand.chrome)
                .frame(width: 14, height: 8)
        }
        .elevation(.floatingBubble(accent: tint))
    }

    private func advanceSparkle() {
        if sparkleScale > 0.01 {
            withAnimation(sparkleShrink) {
                sparkleScale = 0
            }
        } else {
            activeCorner = (activeCorner + 1) % 4
            withAnimation(sparkleGrow) {
                sparkleScale = sparkleMaxScale
            }
        }
    }

    private var sparkleLayer: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let spin = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: sparkleSpinPeriod) / sparkleSpinPeriod * 360

                Image(systemName: sparkleSymbol)
                    .font(.asl(16, weight: .semibold))
                    .foregroundStyle(Color.yellow)
                    .frame(width: 16, height: 16)
                    .scaleEffect(sparkleScale, anchor: .center)
                    .rotationEffect(.degrees(spin))
                    .opacity(sparkleScale <= 0.001 ? 0 : Double(sparkleScale))
                    .position(sparkleCornerPoint(for: activeCorner, in: geo.size))
            }
        }
        .allowsHitTesting(false)
    }

    /// Top left → bottom right → top right → bottom left on the label capsule.
    private func sparkleCornerPoint(for corner: Int, in size: CGSize) -> CGPoint {
        let inset = sparkleCornerInset
        switch corner {
        case 0:
            return CGPoint(x: inset, y: inset)
        case 1:
            return CGPoint(x: size.width - inset, y: size.height - inset)
        case 2:
            return CGPoint(x: size.width - inset, y: inset)
        default:
            return CGPoint(x: inset, y: size.height - inset)
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Unit Header Card

private struct UnitHeaderCard: View {
    /// Nil for phase review checkpoints (not numbered lesson units).
    let unitNumber: Int?
    let title: String
    var subtitle: String? = nil
    let palette: UnitPalette

    private let cornerRadius: CGFloat = PremiumCardMetrics.cornerRadiusMedium

    var body: some View {
        PremiumColoredCard(
            fill: palette.color,
            depthHint: palette.shadow,
            depthMix: PastelCardMetrics.depthMix,
            slabDepth: PastelCardMetrics.slabDepth,
            cornerRadius: cornerRadius,
            isPressed: false
        ) {
            cardContent
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                if let unitNumber {
                    HStack(spacing: 0) {
                        Text("Unit ")
                            .font(.asl(14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(unitNumber)")
                            .font(.asl(14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text(title)
                    .font(.asl(22, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.asl(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer(minLength: 8)
            unitSymbolBadge
        }
        .padding(.horizontal, HomePinnedChrome.unitInnerPaddingH)
        .padding(.vertical, 18)
    }

    private var unitSymbolBadge: some View {
        let size = HomePinnedChrome.unitSymbolFrame

        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            ASLIcon(
                source: .symbol(palette.symbol),
                role: .unitBadge,
                tint: palette.color
            )
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mascot

private enum MascotSide { case leading, trailing }

// MARK: - Scroll-to-top button

private struct ScrollToTopButton: View {
    let palette: UnitPalette
    let action: () -> Void

    private let size: CGFloat = 54

    var body: some View {
        PressableStoneButton(action: action) { isPressed in
            ZStack(alignment: .top) {
                Circle()
                    .fill(PremiumCardStyle.softDepth(for: palette.color, hint: palette.shadow))
                    .frame(width: size, height: size)
                    .offset(y: isPressed ? RaisedCardMetrics.pressedDepthOffset : RaisedCardMetrics.depth)

                Circle()
                    .fill(palette.color)
                    .frame(width: size, height: size)
                    .overlay {
                        ASLIcon(
                            source: .symbol("arrow.up"),
                            role: .toolbar,
                            tint: .white
                        )
                    }
                    .offset(y: isPressed ? RaisedCardMetrics.pressedFaceOffset : 0)
            }
            .frame(width: size, height: size + RaisedCardMetrics.depth, alignment: .top)
            .scaleEffect(isPressed ? RaisedCardMetrics.pressedScale : 1)
            .elevation(.raisedControl(tint: palette.shadow, isPressed: isPressed))
            .animation(RaisedCardMetrics.pressAnimation, value: isPressed)
        }
    }
}

// MARK: - Button Style

private struct PressableStoneButton<Label: View>: View {
    let action: () -> Void
    let label: (Bool) -> Label

    @GestureState private var isPressed = false
    @State private var releasePressed = false
    private let tapMovementTolerance: CGFloat = 10

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping (Bool) -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label(isPressed || releasePressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) <= tapMovementTolerance,
                              abs(value.translation.height) <= tapMovementTolerance
                        else { return }
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

private struct NodePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}

private struct ContinueButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private enum ModulePreviewSheetMetrics {
    static let height: CGFloat = 436
    static let previewIconDiameter: CGFloat = 86
    static let previewIconTopOverlap: CGFloat = previewIconDiameter / 2
    static let dragHandleBlockHeight: CGFloat = 8 + 5 + 4
    /// Keeps the protruding half of the icon inside the sheet (avoids top clipping).
    static let iconTopInset: CGFloat = 50
    static let contentTopInset: CGFloat = 10
    static let bottomInset: CGFloat = 24
    static let statValueSize: CGFloat = 72
    static let statLabelSize: CGFloat = 20

    static var iconRowOrigin: CGFloat { dragHandleBlockHeight + iconTopInset }
    static var contentTopPadding: CGFloat { iconRowOrigin + contentTopInset }
}

private struct ModulePreviewSheet: View {
    let lesson: ASLLesson
    let unit: ASLUnit
    let palette: UnitPalette
    @ObservedObject var store: ASLDataStore
    let onClose: () -> Void
    let onContinue: (LessonEntryRevealRequest) -> Void

    @State private var showResetConfirm = false
    @State private var isContinuingToLesson = false
    @State private var continueButtonFrame: CGRect = .zero

    private var progress: Double {
        store.lessonProgress(for: lesson.id)
    }

    private var hasStoneProgress: Bool {
        progress > 0
    }

    private var totalSteps: Int {
        max(store.modulePlaySteps(for: lesson).count, 1)
    }

    /// Total vocabulary taught across the unit (all stones).
    private var unitSignCount: Int {
        PracticePathContext.wordIds(forUnitId: unit.id, store: store).count
    }

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        ZStack(alignment: .top) {
            Brand.chrome
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 18) {
                    Color.clear
                        .frame(height: ModulePreviewSheetMetrics.previewIconTopOverlap + 12)

                    Text(previewTitle)
                        .aslStyle(.cardTitle, variant: .standard)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 24)

                    ModulePreviewProgressBar(
                        progress: progress,
                        color: palette.color,
                        shadowColor: palette.shadow
                    )
                        .padding(.horizontal, 20)

                    HStack(spacing: 0) {
                        if unit.isReview {
                            stat(value: ASLPhaseReviewCopy.roundCount, label: "Rounds")
                            stat(value: ASLPhaseReviewCopy.questionCount(for: totalSteps), label: "Questions")
                            stat(value: progressPercent, label: "My progress", suffix: "%")
                        } else {
                            stat(value: totalSteps, label: "Total steps")
                            stat(value: unitSignCount, label: "Signs")
                            stat(value: progressPercent, label: "My progress", suffix: "%")
                        }
                    }
                    .padding(.top, 6)

                    PressablePreviewButton(action: tappedContinue) { isPressed in
                        RaisedPreviewButton(
                            title: previewButtonTitle,
                            color: palette.color,
                            shadow: palette.shadow,
                            isPressed: isPressed
                        )
                    }
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ContinueButtonFrameKey.self,
                                value: geo.frame(in: .global)
                            )
                        }
                    }
                    .onPreferenceChange(ContinueButtonFrameKey.self) { frame in
                        continueButtonFrame = frame
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, ModulePreviewSheetMetrics.bottomInset)
            }
            .padding(.top, ModulePreviewSheetMetrics.contentTopPadding)

            ZStack(alignment: .top) {
                previewIcon
                    .offset(
                        y: ModulePreviewSheetMetrics.iconRowOrigin
                            - ModulePreviewSheetMetrics.previewIconTopOverlap
                    )

                previewHeaderButtons
                    .offset(y: ModulePreviewSheetMetrics.iconRowOrigin - 17)
            }
            .zIndex(1)

            Capsule()
                .fill(Brand.divider)
                .frame(width: 42, height: 5)
                .padding(.top, 8)
        }
        .overlay {
            if showResetConfirm {
                ZStack {
                    StoneConfirmScrim()
                        .onTapGesture {
                            Haptics.tap()
                            dismissResetConfirm()
                        }

                    ResetStoneConfirmCard(
                        palette: palette.color,
                        paletteShadow: palette.shadow,
                        keepGoing: dismissResetConfirm,
                        reset: {
                            showResetConfirm = false
                            resetStone()
                        }
                    )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: showResetConfirm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: lesson.id) {
            store.beginLessonMediaSession(lessonId: lesson.id)
            store.preloadStoneCascade(unit: unit, fromStoneSortOrder: lesson.sortOrder)
            store.preloadLessonMedia(lesson: lesson, unit: unit)
            let stepIndex = store.savedStepIndex(
                for: lesson.id,
                totalSteps: store.modulePlaySteps(for: lesson).count
            )
            _ = await store.ensureStepMediaReady(lesson: lesson, unit: unit, stepIndex: stepIndex)
        }
        .onDisappear {
            if !isContinuingToLesson {
                store.endLessonMediaSession(lessonId: lesson.id)
            }
        }
    }

    private func dismissResetConfirm() {
        showResetConfirm = false
    }

    private var previewTitle: String {
        if unit.isReview {
            return unit.phaseTitle ?? unit.title
        }
        return ASLStoneDisplayTitles.title(for: lesson, unit: unit)
    }

    private var previewIcon: some View {
        ZStack {
            Circle()
                .fill(palette.color)
                .frame(
                    width: ModulePreviewSheetMetrics.previewIconDiameter,
                    height: ModulePreviewSheetMetrics.previewIconDiameter
                )

            Image(systemName: unit.isReview ? "flag.checkered.2.crossed" : LessonStoneGlyph.symbol(for: lesson, unit: unit, lessonCount: unit.lessonCount))
                .font(.asl(38, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var previewHeaderButtons: some View {
        HStack {
            if hasStoneProgress {
                Button {
                    Haptics.tap()
                    showResetConfirm = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.asl(15, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 34, height: 34)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
    }

    private var previewButtonTitle: String {
        if progress >= 1 {
            return "Review Again"
        }
        if progress <= 0, lesson.sortOrder == 1 {
            return "Start here!"
        }
        return progress > 0 ? "Continue" : "Start"
    }

    private func tappedContinue() {
        Haptics.tap()
        isContinuingToLesson = true
        let request = LessonEntryRevealRequest(
            fillColor: palette.color,
            origin: CGPoint(x: continueButtonFrame.midX, y: continueButtonFrame.midY),
            lesson: lesson,
            unit: unit
        )
        onContinue(request)
    }

    private func resetStone() {
        Haptics.tap()
        store.resetLessonProgress(lessonId: lesson.id, unitId: unit.id)
    }

    private func stat(value: Int, label: String, suffix: String = "") -> some View {
        VStack(spacing: 8) {
            Text("\(value)\(suffix)")
                .font(.asl(ModulePreviewSheetMetrics.statValueSize, weight: .bold))
                .foregroundStyle(Brand.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.asl(ModulePreviewSheetMetrics.statLabelSize, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ModulePreviewProgressBar: View {
    let progress: Double
    let color: Color
    var shadowColor: Color? = nil

    private let barHeight: CGFloat = PremiumProgressBarMetrics.previewBarHeight

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                PremiumProgressBarTrack(height: barHeight)
                PremiumProgressBarFill(color: color, shadowColor: shadowColor, height: barHeight)
                    .frame(width: barWidth(in: geo))
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .frame(height: barHeight)
    }

    private func barWidth(in geo: GeometryProxy) -> CGFloat {
        let clamped = max(0, min(1, progress))
        let width = geo.size.width * clamped
        guard width > 0 else { return 0 }
        return min(geo.size.width, max(PremiumProgressBarMetrics.minFillWidth, width))
    }
}

private struct RaisedPreviewButton: View {
    let title: String
    let color: Color
    let shadow: Color
    let isPressed: Bool

    private let height: CGFloat = 56
    private let depth: CGFloat = 6

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(shadow)
                .frame(height: height)
                .offset(y: isPressed ? 1.5 : depth)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
                .frame(height: height)
                .overlay(
                    Text(title)
                        .font(.asl(16, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .offset(y: isPressed ? depth - 1.5 : 0)
        }
        .frame(height: height + depth, alignment: .top)
        .scaleEffect(isPressed ? 0.985 : 1)
        .elevation(.raisedControl(tint: shadow, isPressed: isPressed))
        .animation(
            isPressed ? .easeOut(duration: 0.06) : .spring(response: 0.24, dampingFraction: 0.62),
            value: isPressed
        )
    }
}

private struct PressablePreviewButton<Label: View>: View {
    let action: () -> Void
    let label: (Bool) -> Label

    @GestureState private var isPressed = false
    @State private var releasePressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping (Bool) -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label(isPressed || releasePressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onEnded { _ in
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

// Lesson and word drill-down moved into ASL/Tabs/LessonRouter.swift and the
// per-stone gameplay views under ASL/Lessons/.
