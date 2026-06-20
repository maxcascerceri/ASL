import Combine
import Foundation
import AVFoundation
import FirebaseFirestore
import FirebaseStorage

struct DailyStreakCelebrationPayload: Equatable, Codable, Identifiable {
    let previousStreak: Int
    let newStreak: Int
    let dayKey: String

    var id: String { dayKey }
}

/// Playable state for a lesson stone on the home path.
enum HomeLessonNodeState {
    case completed
    case current
    case locked
}

@MainActor
final class ASLDataStore: ObservableObject {
    @Published var paths: [ASLPath] = []
    @Published var unitsByPathId: [String: [ASLUnit]] = [:]
    @Published var lessonsByUnitId: [String: [ASLLesson]] = [:]
    @Published var wordsById: [String: ASLWord] = [:]
    @Published var videosByWordId: [String: [ASLVideo]] = [:]

    @Published var isLoadingPaths = false
    @Published var isLoadingUnits = false
    @Published var isLoadingLessons = false
    @Published var isLoadingLessonWords = false
    @Published var isLoadingVideos = false
    /// Shown on Home when path/unit fetch fails or returns empty.
    @Published private(set) var homeLoadErrorMessage: String?
    /// Per-unit lesson fetch (avoids one global flag hiding stones on every row).
    @Published private(set) var loadingLessonUnitIds: Set<String> = []
    /// Units whose lesson fetch failed (Home can offer retry).
    @Published private(set) var lessonLoadFailedUnitIds: Set<String> = []

    /// Session-local set of units the user has finished. Used by the home
    /// screen to flip the unit's stones to `.completed` and to trigger the
    /// celebratory bump on the stats chip / confetti burst.
    @Published var completedUnitIds: Set<String> = []

    /// The unit the user *just* finished. The home screen reads this to fire
    /// a one-shot confetti burst for milestone units, then clears it.
    @Published var celebratedUnit: ASLUnit?

    /// True while the home unit-completion flow (confetti / auto-start handoff) is active.
    @Published var homeUnitFlowBlocksMedalCelebrations = false

    /// Unit id to auto-open after the learner continues from a unit celebration.
    @Published private(set) var pendingAutoStartUnitId: String?

    /// Queued daily streak celebration shown after qualifying activity on a new calendar day.
    @Published private(set) var pendingDailyStreakCelebration: DailyStreakCelebrationPayload?

    /// True while a practice session complete overlay is visible (defers streak celebration).
    @Published var isPracticeSessionCompleteVisible = false

    /// True while any lesson media session is active (user is inside a unit lesson).
    @Published private(set) var isLessonMediaSessionActive = false

    @Published private(set) var lessonProgressById: [String: Double] = [:]
    private var lessonStepIndexById: [String: Int] = [:]

    /// Running total of stars (lessons, checkpoints, milestones, streaks, dictionary).
    @Published private(set) var totalStars: Int = 0
    /// Best in-lesson answer streak (milestones / internal; not the home header chip).
    @Published private(set) var displayStreak: Int = 0
    /// Consecutive calendar days with at least one learning activity (home header).
    @Published private(set) var dailyActivityStreak: Int = 0
    /// Longest daily activity streak the learner has achieved.
    @Published private(set) var bestDailyActivityStreak: Int = 0
    /// Unique signs learned on the path and/or opened in the dictionary (home header chip).
    @Published private(set) var learnedSignsCount: Int = 0

    /// Word ids from the dictionary and completed lesson stones (for practice vocabulary).
    var studiedSignWordIds: Set<String> {
        learnedWordIdsForStars.union(learnedWordIdsFromPath)
    }

    /// Signs from completed lesson stones only (excludes dictionary study).
    var learnedLessonWordIds: Set<String> {
        learnedWordIdsFromPath
    }

    func learnedLessonWordIds(excluding letterIds: Set<String>) -> [String] {
        learnedWordIdsFromPath
            .filter { !letterIds.contains($0) }
            .sorted {
                ASLWordDisplay.title(for: $0).localizedCaseInsensitiveCompare(
                    ASLWordDisplay.title(for: $1)
                ) == .orderedAscending
            }
    }

    @Published private(set) var quizMediaState: SignMediaCacheState = .idle
    @Published private(set) var mediaCacheRevision = 0
    @Published private(set) var videoPlaybackRevision = 0
    /// True while the Signs tab is visible — defers Sign Sprint video preload.
    @Published var isSignsTabActive = false
    /// Word ids for the open dictionary category/search/favorites scope (prefetch + poster URLs).
    @Published private(set) var activeDictionaryWordIds: Set<String> = []

    private var awardedStarEventIds: Set<String> = []
    /// Signs opened at least once in the Signs dictionary tab.
    private var learnedWordIdsForStars: Set<String> = []
    /// Signs from completed lesson stones on the home path.
    private var learnedWordIdsFromPath: Set<String> = []
    /// Signs the learner has seen on a teach / new-sign screen across completed module stones.
    private(set) var introducedWordIdsOnPath: Set<String> = []
    private(set) var seenASLTipIds: Set<String> = []

    private let seenTipsStorageKey = "asl.seenTips.v1"
    private let progressStorageKey = "asl.lessonProgress.v1"
    private let starsStorageKey = "asl.starProgress.v1"
    private let dailyStreakStorageKey = "asl.dailyStreak.v1"
    private var lastActiveDayStartSince1970: TimeInterval?
    /// Calendar day keys (`yyyy-MM-dd`) with qualifying activity (week strip + history).
    private var activeDayKeys: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var quizPreloadTask: Task<Void, Never>?
    private var quizRefreshTask: Task<Void, Never>?
    private var lessonMediaPreloadTasks: [String: Task<Void, Never>] = [:]
    private var lessonMediaPreloadStates: [String: LessonMediaPreloadState] = [:]
    private var activeLessonMediaSessionCounts: [String: Int] = [:]
    private var deferredFreeRoamMediaRequest: DeferredFreeRoamMediaRequest?
    private var pendingQuizRefresh = false
    private var modulePlayStepsCache: [String: [ModulePlayStep]] = [:]
    /// Bumped whenever path introductions change so cached play queues rebuild.
    private var modulePlayStepsIntroGeneration: Int = 0
    private var freeRoamHomeMediaTask: Task<Void, Never>?
    private let dictionaryVideoWarmPool = DictionaryVideoWarmPool()
    @Published private(set) var dictionaryVideoRevision = 0
    /// Switches main tab bar when routing a daily practice deep link.
    @Published var pendingTabSelection: AppTab?
    /// Opens a dictionary sign detail after switching to the Signs tab.
    @Published var pendingSignWordId: String?
    @Published var pendingPracticeLaunch: PracticeSessionLaunch?

    lazy var practiceDailyEngine: PracticeDailyTaskEngine = {
        PracticeDailyTaskEngine(awardStars: { [weak self] amount, eventId in
            self?.tryAwardStars(amount, eventId: eventId) ?? 0
        })
    }()

    lazy var medalEngine: MedalEngine = {
        let engine = MedalEngine()
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        return engine
    }()

    init() {
        CurriculumThreeStoneMigration.migrateIfNeeded(
            progressStorageKey: progressStorageKey,
            completedUnitsStorageKey: "asl.completedUnitIds.v1"
        )
        CurriculumUnitMigration.migrateLessonProgressIfNeeded(progressStorageKey: progressStorageKey)
        loadStoredSeenTips()
        loadStoredLessonProgress()
        loadStoredStarProgress()
        loadDailyStreak()
    }

    struct StreakDayState: Identifiable {
        let index: Int
        let weekdaySymbol: String
        let isToday: Bool
        let isActive: Bool
        var id: Int { index }
    }

    func streakWeekdayStates(referenceDate: Date = .now) -> [StreakDayState] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }
        let formatter = Self.dayKeyFormatter
        return (0..<7).compactMap { offset -> StreakDayState? in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let key = formatter.string(from: day)
            let weekdayIndex = cal.component(.weekday, from: day) - 1
            let symbols = cal.shortWeekdaySymbols
            let symbol = weekdayIndex < symbols.count
                ? String(symbols[weekdayIndex].prefix(3))
                : "?"
            return StreakDayState(
                index: offset,
                weekdaySymbol: symbol,
                isToday: cal.isDateInToday(day),
                isActive: activeDayKeys.contains(key)
            )
        }
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func markUnitComplete(_ unit: ASLUnit) {
        _ = applyUnitCompletion(unit)
    }

    @discardableResult
    private func applyUnitCompletion(_ unit: ASLUnit) -> (gateway: Int, milestone: Int) {
        completedUnitIds.insert(unit.id)
        celebratedUnit = unit
        homeUnitFlowBlocksMedalCelebrations = true
        recordDailyActivity()
        let gateway = tryAwardStars(
            ASLStarEconomy.unitGatewayBonus,
            eventId: "unitGateway:\(unit.id)"
        )
        var milestone = ASLStarEconomy.everyNthUnitMilestoneBonus(sortOrder: unit.sortOrder, n: 5)
        if milestone > 0 {
            milestone = tryAwardStars(milestone, eventId: "unitEvery5:\(unit.sortOrder)")
        }
        practiceDailyEngine.recordUnitComplete(unitId: unit.id)
        medalEngine.reconcile(with: self)
        return (gateway, milestone)
    }

    func clearCelebration() {
        celebratedUnit = nil
    }

    func endHomeUnitFlowMedalBlocking() {
        homeUnitFlowBlocksMedalCelebrations = false
    }

    func queueAutoStartUnit(_ unitId: String) {
        pendingAutoStartUnitId = unitId
    }

    func clearPendingAutoStartUnit() {
        pendingAutoStartUnitId = nil
    }

    func sortedUnits(for pathId: String) -> [ASLUnit] {
        (unitsByPathId[pathId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Whether a phase-review checkpoint at `index` is unlocked (same rules as the home path).
    func isReviewUnitAvailable(at index: Int, in units: [ASLUnit]) -> Bool {
        guard units.indices.contains(index), units[index].isReview else { return false }
        let blockStart = units[..<index].lastIndex(where: { $0.isReview }).map { $0 + 1 } ?? 0
        let blockUnits = units[blockStart..<index].filter { !$0.isReview }
        guard !blockUnits.isEmpty else { return false }
        return blockUnits.allSatisfy { isUnitComplete($0) }
    }

    /// Next unit the learner can enter after completing `unit`, or nil at path end / locked review.
    func nextPlayableUnit(after unit: ASLUnit) -> ASLUnit? {
        let units = sortedUnits(for: unit.pathId)
        guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return nil }
        let nextIndex = index + 1
        guard units.indices.contains(nextIndex) else { return nil }
        let next = units[nextIndex]
        if next.isReview {
            return isReviewUnitAvailable(at: nextIndex, in: units) ? next : nil
        }
        return next
    }

    /// Re-evaluates the calendar-day streak when the home tab appears (e.g. after midnight).
    func refreshDailyStreakIfNeeded() {
        reconcileDailyStreakWithCalendar()
        medalEngine.reconcile(with: self)
    }

    /// Refreshes header stats when the home screen becomes visible again (e.g. after a lesson).
    func refreshHomeHeaderStats() {
        refreshDailyStreakIfNeeded()
        reconcilePathLearnedWordsFromProgress()
    }

    func lessonProgress(for lessonId: String) -> Double {
        lessonProgressById[lessonId] ?? 0
    }

    func shouldOfferStoneReset(lessonId: String, sessionProgress: Double) -> Bool {
        if sessionProgress > 0.001 { return true }
        return lessonProgress(for: lessonId) > 0
    }

    func resetLessonProgress(lessonId: String, unitId: String?) {
        lessonProgressById.removeValue(forKey: lessonId)
        lessonStepIndexById.removeValue(forKey: lessonId)
        persistLessonProgress()

        if let unitId {
            completedUnitIds.remove(unitId)
            if lessonId.hasSuffix("-l1") {
                ASLStoneMistakeMemory.clearUnit(unitId)
            }
        }
        medalEngine.reconcile(with: self)
    }

    func recordStoneMiss(unitId: String, wordId: String, stoneSortOrder: Int) {
        ASLStoneMistakeMemory.recordMiss(
            unitId: unitId,
            wordId: wordId,
            stoneSortOrder: stoneSortOrder
        )
        invalidateModulePlayStepsCache(forUnitId: unitId)
    }

    func carryoverWord(for unitId: String, stoneSortOrder: Int) -> String? {
        ASLStoneMistakeMemory.peekCarryover(
            unitId: unitId,
            targetStoneSortOrder: stoneSortOrder
        )
    }

    func weakSignWordIdsForPractice(maxCount: Int = 3) -> [String] {
        guard maxCount > 0,
              let unit = PracticePathContext.currentLearningUnit(from: self) else { return [] }
        return ASLStoneMistakeMemory.peekQueue(unitId: unit.id, maxCount: maxCount)
    }

    func markCarryoverSurfaced(unitId: String, wordId: String) {
        ASLStoneMistakeMemory.consumeCarryover(unitId: unitId, wordId: wordId)
    }

    func isUnitComplete(_ unit: ASLUnit) -> Bool {
        if completedUnitIds.contains(unit.id) {
            return true
        }

        if let lessons = lessonsByUnitId[unit.id], !lessons.isEmpty {
            return lessons.allSatisfy { lessonProgress(for: $0.id) >= 1 }
        }

        // Curriculum lesson IDs are deterministic (`unitId-l1`, `unitId-l2`,
        // ...), so this lets home unlock the next unit even before the completed
        // unit's lesson docs have been reloaded in the current app session.
        guard unit.lessonCount > 0 else { return false }
        return (1...unit.lessonCount).allSatisfy { index in
            lessonProgress(for: "\(unit.id)-l\(index)") >= 1
        }
    }

    func hasStartedUnit(_ unit: ASLUnit) -> Bool {
        if let lessons = lessonsByUnitId[unit.id], !lessons.isEmpty {
            return lessons.contains { lessonProgress(for: $0.id) > 0 }
        }

        guard unit.lessonCount > 0 else { return false }
        return (1...unit.lessonCount).contains { index in
            lessonProgress(for: "\(unit.id)-l\(index)") > 0
        }
    }

    /// Sequential stone unlock within a unit: stone 1 is always playable; later
    /// stones unlock when the previous lesson in sort order is complete.
    func lessonNodeState(at index: Int, in lessons: [ASLLesson], unit: ASLUnit) -> HomeLessonNodeState {
        guard lessons.indices.contains(index) else { return .locked }

        let lesson = lessons[index]
        if isUnitComplete(unit) || lessonProgress(for: lesson.id) >= 1 {
            return .completed
        }
        if index == 0 {
            return .current
        }
        let previous = lessons[index - 1]
        if lessonProgress(for: previous.id) >= 1 {
            return .current
        }
        return .locked
    }

    func savedStepIndex(for lessonId: String, totalSteps: Int) -> Int {
        guard totalSteps > 0 else { return 0 }
        if lessonProgress(for: lessonId) >= 1 { return 0 }
        return max(0, min(lessonStepIndexById[lessonId] ?? 0, totalSteps - 1))
    }

    func updateLessonProgress(lessonId: String, currentIndex: Int, totalSteps: Int, isComplete: Bool) {
        guard totalSteps > 0 else { return }
        let previousProgress = lessonProgressById[lessonId] ?? 0
        let clampedIndex = max(0, min(currentIndex, totalSteps))
        let progress = isComplete ? 1.0 : Double(clampedIndex) / Double(totalSteps)
        lessonStepIndexById[lessonId] = isComplete ? 0 : min(clampedIndex, max(0, totalSteps - 1))
        lessonProgressById[lessonId] = progress
        persistLessonProgress()
        if progress > previousProgress + 1e-9 {
            recordDailyActivity()
            medalEngine.reconcile(with: self)
        }
    }

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var preloadingUnitIds: Set<String> = []
    private var preloadedUnitIds: Set<String> = []
    private var loadingVideoWordIds: Set<String> = []

    func isLoadingLessons(for unitId: String) -> Bool {
        loadingLessonUnitIds.contains(unitId)
    }

    func didFailToLoadLessons(for unitId: String) -> Bool {
        lessonLoadFailedUnitIds.contains(unitId)
    }

    /// Reassigns dictionary values so `@Published` emits and SwiftUI refreshes Home.
    private func setUnits(_ units: [ASLUnit], for pathId: String) {
        var map = unitsByPathId
        map[pathId] = units
        unitsByPathId = map
    }

    private func setLessons(_ lessons: [ASLLesson], for unitId: String) {
        var map = lessonsByUnitId
        map[unitId] = lessons
        lessonsByUnitId = map
    }

    private func beginLoadingLessons(for unitId: String) {
        var loading = loadingLessonUnitIds
        var failed = lessonLoadFailedUnitIds
        loading.insert(unitId)
        failed.remove(unitId)
        loadingLessonUnitIds = loading
        lessonLoadFailedUnitIds = failed
        isLoadingLessons = true
    }

    private func endLoadingLessons(for unitId: String) {
        var loading = loadingLessonUnitIds
        loading.remove(unitId)
        loadingLessonUnitIds = loading
        isLoadingLessons = !loading.isEmpty
    }

    private func markLessonLoadFailed(_ unitId: String) {
        var failed = lessonLoadFailedUnitIds
        failed.insert(unitId)
        lessonLoadFailedUnitIds = failed
    }

    /// Clears cached path data and refetches from Firestore (Home retry).
    func reloadHomeCurriculum() {
        homeLoadErrorMessage = nil
        paths = []
        unitsByPathId = [:]
        lessonsByUnitId = [:]
        loadingLessonUnitIds = []
        lessonLoadFailedUnitIds = []
        loadPaths()
    }

    /// Loads path → units → first-screen lessons (call from Home on appear).
    func ensureHomeCurriculumLoaded() async {
        if paths.isEmpty {
            await loadPathsAwait()
        }
        guard let path = paths.first else {
            if homeLoadErrorMessage == nil {
                homeLoadErrorMessage = "Couldn’t load your learning path. Check your connection and try again."
            }
            return
        }
        if unitsByPathId[path.id] == nil {
            await loadUnitsAwait(for: path)
        }
        guard let units = unitsByPathId[path.id], !units.isEmpty else {
            if homeLoadErrorMessage == nil {
                homeLoadErrorMessage = "No units found for your path. Try again in a moment."
            }
            return
        }
        homeLoadErrorMessage = nil
        await bootstrapHomeLessonsAwait(for: units)
    }

    func loadPaths() {
        guard paths.isEmpty else { return }
        isLoadingPaths = true
        homeLoadErrorMessage = nil

        db.collection("paths")
            .order(by: "sortOrder")
            .getDocuments { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoadingPaths = false

                    if let error {
                        self.paths = []
                        self.homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
                        return
                    }

                    self.paths = snapshot?.documents.compactMap(Self.makePath(from:)) ?? []
                    if self.paths.isEmpty {
                        self.homeLoadErrorMessage = "No learning path is published yet."
                        return
                    }
                    if let path = self.paths.first {
                        self.loadUnits(for: path)
                    }
                }
            }
    }

    func loadUnits(for path: ASLPath) {
        guard unitsByPathId[path.id] == nil else { return }
        isLoadingUnits = true

        db.collection("paths")
            .document(path.id)
            .collection("units")
            .order(by: "sortOrder")
            .getDocuments { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoadingUnits = false

                    if let error {
                        self.homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
                        return
                    }

                    let loaded = snapshot?.documents.compactMap(Self.makeUnit(from:)) ?? []
                    guard !loaded.isEmpty else {
                        self.homeLoadErrorMessage = "No units found on your learning path."
                        return
                    }
                    self.setUnits(loaded, for: path.id)
                    self.homeLoadErrorMessage = nil
                    self.bootstrapHomeLessons(for: loaded)
                    self.medalEngine.reconcile(with: self)
                }
            }
    }

    func loadUnitsAwait(for path: ASLPath) async {
        if unitsByPathId[path.id] != nil { return }

        isLoadingUnits = true
        defer { isLoadingUnits = false }

        do {
            let snapshot = try await db.collection("paths")
                .document(path.id)
                .collection("units")
                .order(by: "sortOrder")
                .getDocuments()

            let loaded = snapshot.documents.compactMap(Self.makeUnit(from:))
            guard !loaded.isEmpty else {
                homeLoadErrorMessage = "No units found on your learning path."
                return
            }
            setUnits(loaded, for: path.id)
            homeLoadErrorMessage = nil
            bootstrapHomeLessons(for: loaded)
            medalEngine.reconcile(with: self)
        } catch {
            homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
        }
    }

    func loadLessons(for unit: ASLUnit) {
        guard lessonsByUnitId[unit.id] == nil else { return }
        guard !loadingLessonUnitIds.contains(unit.id) else { return }
        beginLoadingLessons(for: unit.id)

        db.collection("paths")
            .document(unit.pathId)
            .collection("units")
            .document(unit.id)
            .collection("lessons")
            .order(by: "sortOrder")
            .getDocuments { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.endLoadingLessons(for: unit.id)

                    if let error {
                        self.markLessonLoadFailed(unit.id)
                        if self.homeLoadErrorMessage == nil {
                            self.homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
                        }
                        return
                    }

                    let loaded = snapshot?.documents.compactMap(Self.makeLesson(from:)) ?? []
                    guard !loaded.isEmpty else {
                        self.markLessonLoadFailed(unit.id)
                        return
                    }
                    self.setLessons(loaded, for: unit.id)
                    self.reconcilePathLearnedWordsFromProgress()
                }
            }
    }

    func loadLessonsAwait(for unit: ASLUnit) async {
        if lessonsByUnitId[unit.id] != nil { return }
        guard !loadingLessonUnitIds.contains(unit.id) else { return }
        beginLoadingLessons(for: unit.id)
        defer { endLoadingLessons(for: unit.id) }

        do {
            let snapshot = try await db.collection("paths")
                .document(unit.pathId)
                .collection("units")
                .document(unit.id)
                .collection("lessons")
                .order(by: "sortOrder")
                .getDocuments()

            let loaded = snapshot.documents.compactMap(Self.makeLesson(from:))
            guard !loaded.isEmpty else {
                markLessonLoadFailed(unit.id)
                return
            }
            setLessons(loaded, for: unit.id)
            reconcilePathLearnedWordsFromProgress()
        } catch {
            markLessonLoadFailed(unit.id)
            if homeLoadErrorMessage == nil {
                homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
            }
        }
    }

    func loadWords(for lesson: ASLLesson) {
        loadWords(wordIds: lesson.wordIds)
    }

    func loadWords(wordIds: [String]) {
        let missing = Array(Set(wordIds)).filter { wordsById[$0] == nil }
        guard !missing.isEmpty else { return }

        isLoadingLessonWords = true

        Task {
            for chunk in missing.chunked(into: 10) {
                do {
                    let snapshot = try await db.collection("words")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    for document in snapshot.documents {
                        if let word = Self.makeWord(from: document) {
                            self.wordsById[word.id] = word
                        }
                    }
                } catch {
                    continue
                }
            }
            self.isLoadingLessonWords = false
        }
    }

    func loadWordsAwait(wordIds: [String]) async {
        let missing = Array(Set(wordIds)).filter { wordsById[$0] == nil }
        guard !missing.isEmpty else { return }

        isLoadingLessonWords = true
        defer { isLoadingLessonWords = false }

        for chunk in missing.chunked(into: 10) {
            do {
                let snapshot = try await db.collection("words")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for document in snapshot.documents {
                    if let word = Self.makeWord(from: document) {
                        wordsById[word.id] = word
                    }
                }
            } catch {
                continue
            }
        }
        resyncActiveDictionaryPostersIfNeeded()
    }

    func loadVideos(for word: ASLWord) {
        if let existing = videosByWordId[word.id], !existing.isEmpty { return }
        guard !loadingVideoWordIds.contains(word.id) else { return }
        loadingVideoWordIds.insert(word.id)

        isLoadingVideos = true

        db.collection("words")
            .document(word.id)
            .collection("videos")
            .order(by: "sortOrder")
            .getDocuments { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if error != nil {
                        self.isLoadingVideos = false
                        self.loadingVideoWordIds.remove(word.id)
                        if word.videoCount == 0 {
                            self.videosByWordId[word.id] = []
                        }
                        self.bumpVideoPlaybackRevision()
                        return
                    }

                    let loaded = snapshot?.documents.compactMap(Self.makeVideo(from:)) ?? []
                    self.resolvePlaybackURLs(for: word, videos: loaded)
                }
            }
    }

    private func resolvePlaybackURLs(for word: ASLWord, videos loadedVideos: [ASLVideo]) {
        guard !loadedVideos.isEmpty else {
            isLoadingVideos = false
            loadingVideoWordIds.remove(word.id)
            if word.videoCount == 0 {
                videosByWordId[word.id] = []
            }
            bumpVideoPlaybackRevision()
            return
        }

        let sorted = loadedVideos.sorted { $0.sortOrder < $1.sortOrder }
        let pool = Array(sorted.prefix(4))

        Task {
            let chosen = await Self.resolveFirstPlayableVideo(
                wordId: word.id,
                pool: pool,
                storage: self.storage
            )

            self.isLoadingVideos = false
            self.loadingVideoWordIds.remove(word.id)
            if let chosen {
                self.videosByWordId[word.id] = [chosen]
            } else {
                // Keep Firestore metadata for word records.
                self.videosByWordId[word.id] = pool
            }
            self.bumpVideoPlaybackRevision()
        }
    }

    private func bumpVideoPlaybackRevision() {
        videoPlaybackRevision += 1
    }

    func ensureVideoAttached(to controller: LessonPlayerController, wordId: String) async {
        guard let localURL = localMediaFileURL(for: wordId) else { return }
        if controller.loadedWordId == wordId, controller.isPlaybackReady {
            controller.resumeLooping()
            return
        }
        await controller.loadLocal(url: localURL, wordId: wordId)
        if controller.isDisplaying {
            controller.playAtNormalSpeed()
        }
    }

    func warmBundledPlaybackCacheIfNeeded() async {
        await BundledPlaybackCache.warmAllPlaybackFiles()
        dictionaryVideoRevision += 1
    }

    func warmDictionaryVideo(wordId: String, neighborWordIds: [String]) {
        let neighbors = neighborIds(for: wordId, in: neighborWordIds, radius: 1)
        dictionaryVideoWarmPool.setProtectedWordIds(Set(neighbors + [wordId]))
        Task {
            await dictionaryVideoWarmPool.warmPlaybackFiles(wordIds: neighbors + [wordId])
            await dictionaryVideoWarmPool.warmPlayers(wordIds: neighbors + [wordId])
            dictionaryVideoRevision += 1
        }
    }

    func borrowDictionaryController(for wordId: String, neighborWordIds: [String]) async -> LessonPlayerController {
        let started = Date()
        let neighbors = neighborIds(for: wordId, in: neighborWordIds, radius: 1)
        dictionaryVideoWarmPool.setProtectedWordIds(Set(neighbors + [wordId]))

        let controller = await dictionaryVideoWarmPool.borrowController(for: wordId)
        if controller.isPlaybackReady {
            controller.playAtNormalSpeed()
            controller.replay()
        } else {
            Task {
                await dictionaryVideoWarmPool.warmPlayers(wordIds: neighbors)
            }
        }

        recordDictionaryVideoReady(
            wordId: wordId,
            started: started,
            ready: controller.isPlaybackReady && !controller.playbackFailed
        )
        dictionaryVideoRevision += 1
        return controller
    }

    func warmDictionaryGridWord(_ wordId: String) {
        guard isDictionaryFilmed(wordId: wordId) else { return }
        Task {
            await dictionaryVideoWarmPool.warmPlayer(wordId: wordId)
            dictionaryVideoRevision += 1
        }
    }

    func clearDictionaryVideoProtection() {
        dictionaryVideoWarmPool.clearProtectedWordIds()
    }

    private func neighborIds(for wordId: String, in wordIds: [String], radius: Int) -> [String] {
        guard let index = wordIds.firstIndex(of: wordId) else { return [] }
        let lo = max(0, index - radius)
        let hi = min(wordIds.count - 1, index + radius)
        return Array(wordIds[lo...hi])
    }

    func setActiveDictionaryWordIds(_ wordIds: [String]) {
        activeDictionaryWordIds = Set(wordIds)
    }

    func clearActiveDictionaryWordIds() {
        activeDictionaryWordIds = []
    }

    func prepareDictionaryCategory(wordIds: [String]) {
        activeDictionaryWordIds = Set(wordIds)
        let filmed = wordIds.filter { isDictionaryFilmed(wordId: $0) }
        let prefetch = Array(filmed.prefix(DictionaryVideoWarmPool.categoryPrefetchCount))
        Task {
            await dictionaryVideoWarmPool.warmPlaybackFiles(wordIds: filmed)
            await dictionaryVideoWarmPool.warmPlayers(wordIds: prefetch)
            dictionaryVideoRevision += 1
        }
    }

    private func resyncActiveDictionaryPostersIfNeeded() {}

    func isDictionaryFilmed(wordId: String) -> Bool {
        if FilmedSignCatalog.isFilmed(wordId: wordId) { return true }
        return (wordsById[wordId]?.videoCount ?? 0) > 0
    }

    func prepareDictionarySearchResults(wordIds: [String]) {
        activeDictionaryWordIds = Set(wordIds)
    }

    func prepareDictionaryFavorites(wordIds: [String]) {
        activeDictionaryWordIds = Set(wordIds)
    }

    func prepareDictionarySign(wordId: String, in wordIds: [String]) {
        activeDictionaryWordIds = Set(wordIds)
        warmDictionaryVideo(wordId: wordId, neighborWordIds: wordIds)
    }

    func prepareDictionaryDetailPoster(wordId: String) {
        _ = wordId
    }

    func mergeDictionaryVisiblePriority(wordId: String) {
        warmDictionaryGridWord(wordId)
    }

    func recordDictionaryPosterReady(wordId: String, started: Date) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        DictionaryMediaMetrics.shared.recordPoster(wordId: wordId, milliseconds: ms)
        #if DEBUG
        print("[DictionaryMedia] time_to_poster_ms \(wordId): \(ms)")
        #endif
    }

    private func recordDictionaryVideoReady(wordId: String, started: Date, ready: Bool) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        DictionaryMediaMetrics.shared.recordFirstFrame(wordId: wordId, milliseconds: ms, ready: ready)
        #if DEBUG
        print("[DictionaryMedia] time_to_first_video_frame_ms \(wordId): \(ms) ready=\(ready)")
        #endif
    }

    func awaitDictionaryPlaybackReady(wordId: String, timeout: TimeInterval = 25) async -> Bool {
        _ = timeout
        return localMediaFileURL(for: wordId) != nil
    }

    func localPosterURL(for wordId: String) -> URL? {
        BundledSignMedia.posterURL(for: wordId)
    }

    func isPosterReady(for wordId: String) -> Bool {
        BundledSignMedia.posterURL(for: wordId) != nil || !isDictionaryFilmed(wordId: wordId)
    }

    /// Grid disk prefetch + HTTP display (360px thumb).
    func posterStoragePath(for wordId: String) -> String {
        gridPosterStoragePath(for: wordId)
    }

    /// Disk prefetch — prefers 360px thumb when present (falls back to 120 in cache layer).
    func gridPosterStoragePath(for wordId: String) -> String {
        SignMediaPaths.posterGridThumbStoragePath(wordId: wordId)
    }

    /// Grid HTTP — 360px thumb (deployed for all filmed signs).
    func gridPosterHTTPStoragePath(for wordId: String) -> String {
        gridPosterStoragePath(for: wordId)
    }

    func detailPosterStoragePath(for wordId: String) -> String {
        wordsById[wordId]?.posterStoragePath
            ?? SignMediaPaths.posterStoragePath(wordId: wordId)
    }

    func dictionaryMediaURL(storagePath: String) -> URL? {
        DictionaryMediaURL.url(storagePath: storagePath)
    }

    /// Grid poster — bundle, disk cache, then canonical 360px HTTPS thumb.
    func posterDisplayURL(for wordId: String) -> URL? {
        guard isDictionaryFilmed(wordId: wordId) else { return nil }
        if let bundled = BundledSignMedia.posterURL(for: wordId) {
            return bundled
        }
        if let local = localPosterURL(for: wordId) {
            return local
        }
        return dictionaryMediaURL(storagePath: gridPosterHTTPStoragePath(for: wordId))
    }

    /// Detail placeholder — always full-resolution poster JPEG (not grid thumb).
    func detailPosterDisplayURL(for wordId: String) -> URL? {
        guard isDictionaryFilmed(wordId: wordId) else { return nil }
        return dictionaryMediaURL(storagePath: detailPosterStoragePath(for: wordId))
    }

    func setSignsTabActive(_ active: Bool) {
        isSignsTabActive = active
    }

    /// All filmed dictionary signs — background poster warm-up at launch and Signs tab.
    var dictionaryFilmedPosterWordIds: [String] {
        Array(FilmedSignCatalog.wordIds).sorted()
    }

    func syntheticVideo(for wordId: String) async -> ASLVideo? {
        guard isDictionaryFilmed(wordId: wordId) else { return nil }
        guard BundledSignMedia.videoURL(for: wordId) != nil else { return nil }
        let word = wordsById[wordId]
        let storagePath = SignMediaPaths.videoStoragePath(wordId: wordId, fileExtension: "mp4")
        let video = ASLVideo(
            id: "video_001",
            word: word?.text ?? wordId,
            storagePath: storagePath,
            sourcePath: "",
            sortOrder: 1,
            fileSizeBytes: nil,
            playbackURL: nil
        )
        videosByWordId[wordId] = [video]
        return video
    }

    func quizPlaybackURL(for wordId: String) -> URL? {
        videosByWordId[wordId]?.first?.playbackURL
    }

    var isQuizPlayable: Bool {
        let rotation = PracticeQuizCatalog.rotationWordIds(from: self)
        return quizReadyCount(in: rotation) >= PracticeQuizCatalog.minimumPoolSize
    }

    func isMediaReady(wordId: String) -> Bool {
        BundledSignMedia.hasBundledVideo(for: wordId)
    }

    func hasPlayableVideo(for wordId: String) -> Bool {
        BundledSignMedia.isPlayable(wordId: wordId)
    }

    func isLoadingVideo(for wordId: String) -> Bool {
        loadingVideoWordIds.contains(wordId)
    }

    func localMediaFileURL(for wordId: String) -> URL? {
        BundledSignMedia.playbackURL(for: wordId)
    }

    func mediaPlayerItem(for wordId: String) -> AVPlayerItem? {
        guard let url = localMediaFileURL(for: wordId) else { return nil }
        return AVPlayerItem(url: url)
    }

    func quizReadyCount(in wordIds: [String]) -> Int {
        wordIds.filter { BundledSignMedia.hasBundledVideo(for: $0) }.count
    }

    func quizLocalFileURL(for wordId: String) -> URL? {
        localMediaFileURL(for: wordId)
    }

    func quizPlayerItem(for wordId: String) -> AVPlayerItem? {
        mediaPlayerItem(for: wordId)
    }

    @discardableResult
    func attachVideo(
        to controller: LessonPlayerController,
        wordId: String
    ) -> Bool {
        guard let localURL = localMediaFileURL(for: wordId) else { return false }
        controller.load(localURL, wordId: wordId)
        controller.playAtNormalSpeed()
        controller.replay()
        return true
    }

    func attachModuleVideo(to controller: LessonPlayerController, wordId: String) {
        Task {
            await ensureVideoAttached(to: controller, wordId: wordId)
        }
    }

    func attachModuleVideo(to controller: LessonPlayerController, wordIds: [String]) {
        guard let wordId = wordIds.first else { return }
        attachModuleVideo(to: controller, wordId: wordId)
    }

    @discardableResult
    func attachVideo(to controller: LessonPlayerController, wordIds: [String]) -> Bool {
        for wordId in wordIds {
            if attachVideo(to: controller, wordId: wordId) {
                return true
            }
        }
        return false
    }

    func prioritizeMediaDownload(wordIds: [String]) {
        _ = wordIds
    }

    func prioritizeQuizLookahead(wordIds: [String]) {
        _ = wordIds
    }

    func preloadLessonMedia(lesson: ASLLesson, unit: ASLUnit, priorityStepIndex: Int? = nil) {
        let stepIndex: Int? = {
            if let priorityStepIndex { return priorityStepIndex }
            guard lesson.type == .module else { return 0 }
            let steps = modulePlaySteps(for: lesson)
            return savedStepIndex(for: lesson.id, totalSteps: steps.count)
        }()

        let wordIds = LessonMediaPlanner.prioritizedWordIds(
            for: lesson,
            store: self,
            unit: unit,
            stepIndex: stepIndex
        )
        guard !wordIds.isEmpty else { return }

        mergeLessonMediaPreload(lessonId: lesson.id, wordIds: wordIds)
        startLessonMediaPreloadTaskIfNeeded(lesson: lesson, unit: unit)
    }

    func cancelLessonMediaPreload(lessonId: String) {
        lessonMediaPreloadTasks[lessonId]?.cancel()
        lessonMediaPreloadTasks.removeValue(forKey: lessonId)
        lessonMediaPreloadStates.removeValue(forKey: lessonId)
    }

    func beginLessonMediaSession(lessonId: String) {
        let count = (activeLessonMediaSessionCounts[lessonId] ?? 0) + 1
        activeLessonMediaSessionCounts[lessonId] = count
        syncLessonMediaSessionActive()
        guard count == 1 else { return }
        freeRoamHomeMediaTask?.cancel()
        freeRoamHomeMediaTask = nil
    }

    func endLessonMediaSession(lessonId: String) {
        guard let count = activeLessonMediaSessionCounts[lessonId], count > 0 else { return }
        if count == 1 {
            activeLessonMediaSessionCounts.removeValue(forKey: lessonId)
            cancelLessonMediaPreload(lessonId: lessonId)
            resumeDeferredFreeRoamIfNeeded()
            if pendingQuizRefresh, activeLessonMediaSessionCounts.isEmpty {
                pendingQuizRefresh = false
                Task { await refreshQuizPreloadIfNeeded(force: true) }
            }
        } else {
            activeLessonMediaSessionCounts[lessonId] = count - 1
        }
        syncLessonMediaSessionActive()
    }

    private func syncLessonMediaSessionActive() {
        let active = !activeLessonMediaSessionCounts.isEmpty
        guard isLessonMediaSessionActive != active else { return }
        isLessonMediaSessionActive = active
    }

    func ensureStepMediaReady(lesson: ASLLesson, unit: ASLUnit, stepIndex: Int) async -> Bool {
        _ = unit
        let steps = modulePlaySteps(for: lesson)
        guard steps.indices.contains(stepIndex) else { return false }
        let wordIds = steps[stepIndex].allReferencedWordIds
        guard !wordIds.isEmpty else { return true }
        await loadWordsAwait(wordIds: wordIds)
        return wordIds.allSatisfy { wordId in
            localMediaFileURL(for: wordId) != nil
                || !isDictionaryFilmed(wordId: wordId)
                || ASLPendingFilmCatalog.wordIds.contains(wordId)
        }
    }

    func modulePlaySteps(for lesson: ASLLesson) -> [ModulePlayStep] {
        let key = modulePlayStepsCacheKey(for: lesson)
        if let cached = modulePlayStepsCache[key] {
            return cached
        }
        let steps = ModuleLessonView.buildPlaySteps(for: lesson, store: self)
        modulePlayStepsCache[key] = steps
        return steps
    }

    func invalidateModulePlayStepsCache(forUnitId unitId: String) {
        invalidateAllModulePlayStepsCache()
    }

    private func invalidateAllModulePlayStepsCache() {
        modulePlayStepsIntroGeneration += 1
        modulePlayStepsCache.removeAll()
    }

    /// Records that the learner has seen this sign's teach / new-sign screen on the path.
    func markWordIntroducedOnPath(_ wordId: String) {
        let trimmed = wordId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let previousIntroduced = introducedWordIdsOnPath
        let previousPath = learnedWordIdsFromPath
        introducedWordIdsOnPath.insert(trimmed)
        learnedWordIdsFromPath.insert(trimmed)
        guard introducedWordIdsOnPath != previousIntroduced || learnedWordIdsFromPath != previousPath else { return }
        invalidateAllModulePlayStepsCache()
        refreshLearnedSignsCount()
        persistStarProgress()
        medalEngine.reconcile(with: self)
    }

    private func modulePlayStepsCacheKey(for lesson: ASLLesson) -> String {
        let carryover = carryoverWord(for: lesson.unitId, stoneSortOrder: lesson.sortOrder) ?? ""
        return "\(lesson.id)|\(carryover)|\(modulePlayStepsIntroGeneration)"
    }

    private func allModuleLessonsInPathOrder() -> [ASLLesson] {
        guard let path = paths.first else { return [] }
        let units = (unitsByPathId[path.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
        var ordered: [ASLLesson] = []
        for unit in units {
            let lessons = (lessonsByUnitId[unit.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
            ordered.append(contentsOf: lessons)
        }
        return ordered
    }

    private func mergeLessonMediaPreload(lessonId: String, wordIds: [String]) {
        var state = lessonMediaPreloadStates[lessonId] ?? LessonMediaPreloadState()
        state.wordIds = Self.orderedUnique(wordIds + state.wordIds.filter { !wordIds.contains($0) })
        lessonMediaPreloadStates[lessonId] = state
    }

    private func startLessonMediaPreloadTaskIfNeeded(lesson: ASLLesson, unit: ASLUnit) {
        _ = unit
        let lessonId = lesson.id
        if lessonMediaPreloadTasks[lessonId] != nil { return }

        let task = Task { @MainActor in
            defer { lessonMediaPreloadTasks.removeValue(forKey: lessonId) }
            guard let state = lessonMediaPreloadStates[lessonId] else { return }
            await loadWordsAwait(wordIds: state.wordIds)
        }
        lessonMediaPreloadTasks[lessonId] = task
    }

    private static func orderedUnique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    func ensureVideoLoaded(for wordId: String) async {
        if quizPlaybackURL(for: wordId) != nil { return }
        if loadingVideoWordIds.contains(wordId) { return }

        guard let word = wordsById[wordId] else { return }

        loadingVideoWordIds.insert(wordId)
        defer { loadingVideoWordIds.remove(wordId) }

        do {
            guard let pool = try await fetchSignVideoPool(for: wordId) else {
                videosByWordId[wordId] = []
                bumpVideoPlaybackRevision()
                return
            }

            if let resolved = await Self.resolveFirstPlayableVideo(
                wordId: wordId,
                pool: pool,
                storage: storage
            ) {
                videosByWordId[wordId] = [resolved]
            } else {
                videosByWordId[wordId] = pool
            }
            bumpVideoPlaybackRevision()
        } catch {
            if wordsById[wordId]?.videoCount == 0 {
                videosByWordId[wordId] = []
            }
            bumpVideoPlaybackRevision()
        }
    }

    func refreshQuizPreloadIfNeeded(force: Bool = false) async {
        _ = force
        await ensureUnitOneLessonsIfNeeded()
        let rotation = PracticeQuizCatalog.rotationWordIds(from: self)
        guard rotation.count >= PracticeQuizCatalog.minimumPoolSize else {
            quizMediaState = .idle
            return
        }
        await loadWordsAwait(wordIds: rotation)
        publishQuizMediaState(for: rotation)
    }

    func preloadQuizDelta(_ wordIds: [String]) async {
        guard !wordIds.isEmpty else { return }
        PracticeQuizCatalog.invalidateRotation()
        await refreshQuizPreloadIfNeeded(force: true)
    }

    private func scheduleQuizPreloadRefresh(delta: Set<String>) {
        guard !delta.isEmpty else { return }
        quizPreloadTask?.cancel()
        quizPreloadTask = Task { @MainActor in
            await preloadQuizDelta(Array(delta))
        }
    }

    private func publishQuizMediaState(for rotation: [String]) {
        let ready = quizReadyCount(in: rotation)
        if ready >= rotation.count {
            quizMediaState = .ready
        } else if ready >= PracticeQuizCatalog.minimumPoolSize {
            quizMediaState = .partial(ready: ready, total: rotation.count)
        } else {
            quizMediaState = .partial(ready: ready, total: rotation.count)
        }
    }

    private func ensureUnitOneLessonsIfNeeded() async {
        let letterIds = Set(PracticeAlphabet.letterWordIds)
        guard learnedLessonWordIds(excluding: letterIds).isEmpty else { return }

        if paths.isEmpty {
            await loadPathsAwait()
        }
        if let path = paths.first, unitsByPathId[path.id] == nil {
            await loadUnitsAwait(for: path)
        }
        guard let unit = PracticePathContext.primaryUnits(from: self).first else { return }
        await loadLessonsAwait(for: unit)
    }

    private func loadPathsAwait() async {
        guard paths.isEmpty else { return }

        isLoadingPaths = true
        defer { isLoadingPaths = false }

        do {
            let snapshot = try await db.collection("paths")
                .order(by: "sortOrder")
                .getDocuments()
            paths = snapshot.documents.compactMap(Self.makePath(from:))
            if paths.isEmpty {
                homeLoadErrorMessage = "No learning path is published yet."
            } else {
                homeLoadErrorMessage = nil
            }
        } catch {
            paths = []
            homeLoadErrorMessage = Self.homeLoadErrorDescription(error)
        }
    }

    /// Eagerly loads lessons for the first home units so stones appear without scrolling.
    private func bootstrapHomeLessons(for units: [ASLUnit]) {
        loadLessonsForUnitsWithSavedProgress(in: units)

        let bootstrapCount = 10
        for unit in units.filter({ !$0.isReview }).prefix(bootstrapCount) {
            if lessonsByUnitId[unit.id] == nil {
                loadLessons(for: unit)
            }
        }
    }

    private func bootstrapHomeLessonsAwait(for units: [ASLUnit]) async {
        loadLessonsForUnitsWithSavedProgress(in: units)

        let bootstrapCount = 10
        for unit in units.filter({ !$0.isReview }).prefix(bootstrapCount) {
            if lessonsByUnitId[unit.id] == nil {
                await loadLessonsAwait(for: unit)
            }
        }
    }

    private static func homeLoadErrorDescription(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain,
           ns.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "Firestore blocked read access. Publish rules that allow reading paths, units, and lessons."
        }
        return "Couldn’t load curriculum (\(error.localizedDescription))."
    }

    func resolveSignVideo(for wordId: String) async -> ASLVideo? {
        await resolveChosenVideo(for: wordId)
    }

    func resolveChosenVideo(for wordId: String) async -> ASLVideo? {
        if let existing = videosByWordId[wordId]?.first, !existing.storagePath.isEmpty {
            return existing
        }

        do {
            guard let chosen = try await fetchChosenSignVideo(for: wordId) else {
                if wordsById[wordId]?.videoCount == 0 {
                    videosByWordId[wordId] = []
                }
                return nil
            }
            videosByWordId[wordId] = [chosen]
            return chosen
        } catch {
            if wordsById[wordId]?.videoCount == 0 {
                videosByWordId[wordId] = []
            }
            return nil
        }
    }

    private func fetchSignVideoPool(for wordId: String) async throws -> [ASLVideo]? {
        let snapshot = try await db.collection("words")
            .document(wordId)
            .collection("videos")
            .order(by: "sortOrder")
            .getDocuments()

        let loaded = snapshot.documents.compactMap(Self.makeVideo(from:))
        guard !loaded.isEmpty else { return nil }

        let sorted = loaded.sorted { $0.sortOrder < $1.sortOrder }
        return Array(sorted.prefix(4))
    }

    private func fetchChosenSignVideo(for wordId: String) async throws -> ASLVideo? {
        guard let pool = try await fetchSignVideoPool(for: wordId) else { return nil }
        return Self.rotatedVideoPool(wordId: wordId, pool: pool).first
    }

    func preloadMedia(for unit: ASLUnit) {
        guard !preloadedUnitIds.contains(unit.id), !preloadingUnitIds.contains(unit.id) else { return }
        guard let lessons = lessonsByUnitId[unit.id], !lessons.isEmpty else { return }

        preloadingUnitIds.insert(unit.id)
        preloadedUnitIds.insert(unit.id)

        Task { @MainActor in
            for lesson in lessons.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                preloadLessonMedia(lesson: lesson, unit: unit)
            }
            preloadingUnitIds.remove(unit.id)
        }
    }

    func preloadContinueLessonIfPossible(units: [ASLUnit], lessonId: String?) {
        guard let lessonId else { return }
        guard let match = lessonAndUnit(for: lessonId, in: units) else { return }
        preloadLessonMedia(lesson: match.lesson, unit: match.unit)
    }

    func preloadStoneOneMedia(for unit: ASLUnit) {
        preloadStoneCascade(unit: unit, fromStoneSortOrder: 1)
    }

    /// Warms current stone plus the next two stones in the same unit.
    func preloadStoneCascade(unit: ASLUnit, fromStoneSortOrder: Int) {
        guard let lessons = lessonsByUnitId[unit.id], !lessons.isEmpty else { return }
        let sorted = lessons.sorted { $0.sortOrder < $1.sortOrder }
        var protectedWordIds: [String] = []

        for lesson in sorted where lesson.sortOrder >= fromStoneSortOrder && lesson.sortOrder <= fromStoneSortOrder + 2 {
            protectedWordIds.append(contentsOf: LessonMediaPlanner.allVideoWordIds(
                for: lesson,
                store: self,
                unit: unit
            ))
        }
        _ = protectedWordIds

        for lesson in sorted where lesson.sortOrder >= fromStoneSortOrder && lesson.sortOrder <= fromStoneSortOrder + 2 {
            preloadLessonMedia(lesson: lesson, unit: unit, priorityStepIndex: 0)
        }
    }

    /// Loads lesson metadata and stone-1 videos for prioritized home units.
    func prepareFreeRoamHomeMedia(units: [ASLUnit], priorityUnitIndices: [Int]) {
        guard !units.isEmpty else { return }
        guard !isLessonMediaSessionActive else {
            deferredFreeRoamMediaRequest = DeferredFreeRoamMediaRequest(
                units: units,
                priorityUnitIndices: priorityUnitIndices
            )
            return
        }

        freeRoamHomeMediaTask?.cancel()
        freeRoamHomeMediaTask = Task { @MainActor in
            let playable = units.enumerated().filter { !$0.element.isReview }
            let prioritySet = Set(priorityUnitIndices)
            let prioritized = playable
                .filter { prioritySet.contains($0.offset) }
                .sorted { lhs, rhs in
                    let lhsRank = priorityUnitIndices.firstIndex(of: lhs.offset) ?? Int.max
                    let rhsRank = priorityUnitIndices.firstIndex(of: rhs.offset) ?? Int.max
                    return lhsRank < rhsRank
                }
                .map(\.element)

            for unit in prioritized {
                guard !Task.isCancelled else { return }
                if lessonsByUnitId[unit.id] == nil {
                    await loadLessonsAwait(for: unit)
                }
                preloadStoneOneMedia(for: unit)
            }
        }
    }

    private func resumeDeferredFreeRoamIfNeeded() {
        guard !isLessonMediaSessionActive,
              let request = deferredFreeRoamMediaRequest else { return }
        deferredFreeRoamMediaRequest = nil
        prepareFreeRoamHomeMedia(
            units: request.units,
            priorityUnitIndices: request.priorityUnitIndices
        )
    }

    /// Priority stone-1 warm-up for the pinned header unit and scroll neighbors.
    func preloadStoneOneMediaNear(activeIndex: Int, in units: [ASLUnit], radius: Int = 2) {
        guard !units.isEmpty else { return }
        let lo = max(0, activeIndex - radius)
        let hi = min(units.count - 1, activeIndex + radius)

        for index in lo...hi {
            let unit = units[index]
            guard !unit.isReview else { continue }
            if lessonsByUnitId[unit.id] == nil {
                loadLessons(for: unit)
            } else {
                preloadStoneOneMedia(for: unit)
            }
        }
    }

    func lessonAndUnit(for lessonId: String, in units: [ASLUnit]) -> (lesson: ASLLesson, unit: ASLUnit)? {
        for unit in units {
            guard let lessons = lessonsByUnitId[unit.id] else { continue }
            if let lesson = lessons.first(where: { $0.id == lessonId }) {
                return (lesson, unit)
            }
        }
        return nil
    }

    private static func rotatedVideoPool(wordId: String, pool: [ASLVideo]) -> [ASLVideo] {
        guard !pool.isEmpty else { return [] }
        let start = stableRotationIndex(for: wordId, poolSize: pool.count)
        return Array(pool[start...]) + Array(pool[..<start])
    }

    private static func resolveFirstPlayableVideo(
        wordId: String,
        pool: [ASLVideo],
        storage: Storage
    ) async -> ASLVideo? {
        let bucket = storage.reference().bucket
        for candidate in rotatedVideoPool(wordId: wordId, pool: pool) {
            var resolved = candidate
            do {
                resolved.playbackURL = try await storage.reference(withPath: resolved.storagePath).downloadURL()
                return resolved
            } catch {
                if let fallback = publicMediaURL(bucket: bucket, storagePath: resolved.storagePath) {
                    resolved.playbackURL = fallback
                    return resolved
                }
            }
        }
        return nil
    }

    /// Tokenless HTTPS URL when Storage rules allow public read (Admin uploads often omit download tokens).
    private static func publicMediaURL(bucket: String, storagePath: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = storagePath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        let pathEncoded = encoded.replacingOccurrences(of: "/", with: "%2F")
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(pathEncoded)?alt=media")
    }

    private static func stableRotationIndex(for wordId: String, poolSize: Int) -> Int {
        guard poolSize > 0 else { return 0 }
        var hash: UInt64 = 1469598103934665603
        for byte in wordId.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(poolSize))
    }

    private static func makePath(from document: QueryDocumentSnapshot) -> ASLPath? {
        let data = document.data()
        guard let title = data["title"] as? String else { return nil }
        return ASLPath(
            id: document.documentID,
            title: title,
            tagline: data["tagline"] as? String ?? "",
            colorHex: data["color"] as? String ?? "#22C55E",
            sortOrder: intValue(from: data["sortOrder"]) ?? 0,
            unitCount: intValue(from: data["unitCount"]) ?? 0
        )
    }

    private static func makeUnit(from document: QueryDocumentSnapshot) -> ASLUnit? {
        let data = document.data()
        guard
            let pathId = data["pathId"] as? String,
            let title = data["title"] as? String
        else {
            return nil
        }
        let phaseKey = (data["phaseKey"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let phaseTitle = (data["phaseTitle"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return ASLUnit(
            id: document.documentID,
            pathId: pathId,
            title: title,
            description: data["description"] as? String ?? "",
            badge: data["badge"] as? String ?? "",
            sortOrder: intValue(from: data["sortOrder"]) ?? 0,
            mandatoryGateway: data["mandatoryGateway"] as? Bool ?? false,
            isReview: data["isReview"] as? Bool ?? false,
            isPhaseReview: data["isPhaseReview"] as? Bool ?? data["isReview"] as? Bool ?? false,
            isMilestone: data["isMilestone"] as? Bool ?? false,
            lessonCount: intValue(from: data["lessonCount"]) ?? 0,
            phaseKey: phaseKey,
            phaseTitle: phaseTitle
        )
    }

    private static func makeLesson(from document: QueryDocumentSnapshot) -> ASLLesson? {
        let data = document.data()
        guard
            let pathId = data["pathId"] as? String,
            let unitId = data["unitId"] as? String,
            let title = data["title"] as? String
        else {
            return nil
        }
        let rawType = data["type"] as? String ?? (data["types"] as? [String])?.first ?? ""
        let type = ASLLessonType(raw: rawType)
        let questions = (data["questions"] as? [[String: Any]] ?? []).compactMap(Self.makeFillGapQuestion(from:))
        let steps = (data["steps"] as? [[String: Any]] ?? []).compactMap(Self.makeModuleStep(from:))
        let timePerQuestionMs = data["timePerQuestionMs"] as? Int
        let config = (data["config"] as? [String: Any]).flatMap(Self.makeCheckpointConfig(from:))

        return ASLLesson(
            id: document.documentID,
            pathId: pathId,
            unitId: unitId,
            title: title,
            displayTitle: data["displayTitle"] as? String,
            type: type,
            sortOrder: intValue(from: data["sortOrder"]) ?? 0,
            wordIds: data["wordIds"] as? [String] ?? [],
            questions: questions,
            steps: steps,
            timePerQuestionMs: timePerQuestionMs,
            config: config
        )
    }

    private static func makeFillGapQuestion(from raw: [String: Any]) -> FillGapQuestion? {
        guard
            let answer = raw["answerWordId"] as? String
        else { return nil }
        return FillGapQuestion(
            sentenceBefore: raw["sentenceBefore"] as? String ?? "",
            sentenceAfter: raw["sentenceAfter"] as? String ?? "",
            answerWordId: answer,
            distractorWordIds: raw["distractorWordIds"] as? [String] ?? []
        )
    }

    private static func makeModuleStep(from raw: [String: Any]) -> ModuleStep? {
        guard let rawKind = raw["kind"] as? String else { return nil }
        return ModuleStep(
            kind: ModuleStepKind(raw: rawKind),
            wordId: raw["wordId"] as? String,
            answerWordId: raw["answerWordId"] as? String,
            comparisonWordId: raw["comparisonWordId"] as? String,
            sentenceBefore: raw["sentenceBefore"] as? String ?? "",
            sentenceAfter: raw["sentenceAfter"] as? String ?? "",
            distractorWordIds: raw["distractorWordIds"] as? [String] ?? [],
            pairWordIds: raw["pairWordIds"] as? [String] ?? [],
            sequenceWordIds: raw["sequenceWordIds"] as? [String] ?? [],
            slotIndex: raw["slotIndex"] as? Int,
            questionWordIds: raw["questionWordIds"] as? [String] ?? [],
            choiceCount: raw["choiceCount"] as? Int,
            timePerQuestionMs: raw["timePerQuestionMs"] as? Int,
            title: raw["title"] as? String ?? "",
            prompt: raw["prompt"] as? String ?? "",
            correctChoice: raw["correctChoice"] as? String ?? "",
            tipId: raw["tipId"] as? String
        )
    }

    private static func makeCheckpointConfig(from raw: [String: Any]) -> CheckpointConfig? {
        let distributionRaw = raw["distribution"] as? [String: Any] ?? [:]
        let distribution = CheckpointDistribution(
            watchPick2: doubleValue(distributionRaw["watchPick2"]) ?? CheckpointDistribution.defaultSplit.watchPick2,
            watchPick4: doubleValue(distributionRaw["watchPick4"]) ?? CheckpointDistribution.defaultSplit.watchPick4,
            fillGap: doubleValue(distributionRaw["fillGap"]) ?? CheckpointDistribution.defaultSplit.fillGap
        )
        let redrillRaw = raw["redrillType"] as? String ?? CheckpointConfig.defaults.redrillType.rawValue
        return CheckpointConfig(
            passRatio: doubleValue(raw["passRatio"]) ?? CheckpointConfig.defaults.passRatio,
            lengthMultiplier: raw["lengthMultiplier"] as? Int ?? CheckpointConfig.defaults.lengthMultiplier,
            distribution: distribution,
            redrillType: ASLLessonType(raw: redrillRaw),
            redrillPassRatio: doubleValue(raw["redrillPassRatio"]) ?? CheckpointConfig.defaults.redrillPassRatio,
            selfSignFinale: raw["selfSignFinale"] as? Bool ?? CheckpointConfig.defaults.selfSignFinale
        )
    }

    private static func intValue(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let int64 = value as? Int64 { return Int(int64) }
        if let double = value as? Double { return Int(double) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let int64 = value as? Int64 { return Double(int64) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func makeWord(from document: DocumentSnapshot) -> ASLWord? {
        guard let data = document.data() else { return nil }
        guard let text = data["text"] as? String else { return nil }

        return ASLWord(
            id: document.documentID,
            text: text,
            normalizedText: data["normalizedText"] as? String ?? text.lowercased(),
            videoCount: data["videoCount"] as? Int ?? 0,
            categoryIds: data["categoryIds"] as? [String] ?? [],
            posterStoragePath: data["posterStoragePath"] as? String
        )
    }

    private static func makeVideo(from document: QueryDocumentSnapshot) -> ASLVideo? {
        let data = document.data()
        guard
            let word = data["word"] as? String,
            let storagePath = data["storagePath"] as? String
        else {
            return nil
        }

        return ASLVideo(
            id: document.documentID,
            word: word,
            storagePath: storagePath,
            sourcePath: data["sourcePath"] as? String ?? "",
            sortOrder: data["sortOrder"] as? Int ?? 0,
            fileSizeBytes: Self.int64Value(from: data["fileSizeBytes"]),
            playbackURL: nil
        )
    }

    private static func int64Value(from value: Any?) -> Int64? {
        if let intValue = value as? Int {
            return Int64(intValue)
        }
        if let int64Value = value as? Int64 {
            return int64Value
        }
        if let doubleValue = value as? Double {
            return Int64(doubleValue)
        }
        return nil
    }

    private func loadStoredSeenTips() {
        guard
            let data = UserDefaults.standard.data(forKey: seenTipsStorageKey),
            let stored = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        seenASLTipIds = Set(stored)
    }

    private func persistSeenTips() {
        guard let data = try? JSONEncoder().encode(Array(seenASLTipIds).sorted()) else { return }
        UserDefaults.standard.set(data, forKey: seenTipsStorageKey)
    }

    func markASLTipSeen(_ tipId: String) {
        let trimmed = tipId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard seenASLTipIds.insert(trimmed).inserted else { return }
        persistSeenTips()
    }

    private func loadStoredLessonProgress() {
        guard
            let data = UserDefaults.standard.data(forKey: progressStorageKey),
            let stored = try? JSONDecoder().decode([String: LessonProgressSnapshot].self, from: data)
        else { return }

        lessonProgressById = stored.mapValues(\.progress)
        lessonStepIndexById = stored.mapValues(\.stepIndex)
    }

    private func persistLessonProgress() {
        let ids = Set(lessonProgressById.keys).union(lessonStepIndexById.keys)
        let snapshots = Dictionary(uniqueKeysWithValues: ids.map { id in
            (
                id,
                LessonProgressSnapshot(
                    progress: lessonProgressById[id] ?? 0,
                    stepIndex: lessonStepIndexById[id] ?? 0
                )
            )
        })

        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: progressStorageKey)
        }
    }

    // MARK: - Stars

    /// Awards stone stars and, when finishing a unit, unit gateway/milestone bonuses.
    /// Returns a breakdown for celebration UI.
    func awardStoneCompletion(
        lesson: ASLLesson,
        unit: ASLUnit,
        sessionBestStreak: Int,
        firstPassPerfect: Bool,
        finishesUnit: Bool
    ) -> StoneCompletionAward {
        updateDisplayStreak(sessionBestStreak)
        recordWordsLearnedFromLesson(lesson)
        invalidateModulePlayStepsCache(forUnitId: lesson.unitId)

        let stoneBase = ASLStarEconomy.moduleStoneReward(sortOrder: lesson.sortOrder)
        let perfectBonus = firstPassPerfect ? ASLStarEconomy.modulePerfectPassBonus : 0
        let stoneAmount = stoneBase + perfectBonus
        let stoneAwarded = tryAwardStars(stoneAmount, eventId: "lesson:\(lesson.id)")

        let breakdownStone: Int
        let breakdownPerfect: Int
        if stoneAwarded > 0 {
            breakdownStone = stoneBase
            breakdownPerfect = perfectBonus
        } else {
            breakdownStone = 0
            breakdownPerfect = 0
        }

        var unitGateway = 0
        var unitMilestone = 0
        if finishesUnit {
            let unitStars = applyUnitCompletion(unit)
            unitGateway = unitStars.gateway
            unitMilestone = unitStars.milestone
        }

        return StoneCompletionAward(
            stone: breakdownStone,
            perfectBonus: breakdownPerfect,
            unitGateway: unitGateway,
            unitMilestone: unitMilestone
        )
    }

    func awardStreakMilestone(lessonId: String, streak: Int) {
        guard ASLStarEconomy.inLessonStreakCelebrationThresholds.contains(streak) else { return }
        medalEngine.recordInLessonStreakMilestone()
        medalEngine.reconcile(with: self)
    }

    func recordPracticeSessionComplete(mode: PracticeMode, unitId: String? = nil) {
        practiceDailyEngine.recordSessionComplete(for: mode, unitId: unitId)
        medalEngine.recordPracticeSession(mode: mode)
        medalEngine.reconcile(with: self)
    }

    func recordQuizSessionComplete(unitId: String? = nil) {
        practiceDailyEngine.recordSessionComplete(for: .quiz, unitId: unitId)
        medalEngine.recordPracticeSession(mode: .quiz)
        medalEngine.reconcile(with: self)
    }

    func acknowledgeTabSelection() {
        pendingTabSelection = nil
    }

    func requestSignDictionary(wordId: String) {
        pendingSignWordId = wordId
        pendingTabSelection = .signs
    }

    func consumePendingSignWordId() -> String? {
        defer { pendingSignWordId = nil }
        return pendingSignWordId
    }

    func queueSpellYourNamePractice(intent: FingerspellNameIntent = .personalName) {
        pendingPracticeLaunch = PracticeSessionLaunch(
            mode: .spellYourName,
            wordIds: [],
            spellIntent: intent
        )
        pendingTabSelection = .practice
    }

    func consumePendingPracticeLaunch() -> PracticeSessionLaunch? {
        defer { pendingPracticeLaunch = nil }
        return pendingPracticeLaunch
    }

    func recordDailyActivity() {
        recordDailyActivityInternal()
    }

    func setPracticeSessionCompleteVisible(_ visible: Bool) {
        isPracticeSessionCompleteVisible = visible
    }

    func clearPendingDailyStreakCelebration() {
        guard pendingDailyStreakCelebration != nil else { return }
        pendingDailyStreakCelebration = nil
        persistDailyStreak()
    }

    /// First-open of a dictionary sign grants stars once per word id.
    func recordSignStudied(wordId: String) {
        recordDailyActivityInternal()
        practiceDailyEngine.recordSignStudied(wordId: wordId)
        let gained = tryAwardStars(ASLStarEconomy.wordStudied, eventId: "wordLearned:\(wordId)")
        if gained > 0 {
            learnedWordIdsForStars.insert(wordId)
            refreshLearnedSignsCount()
            persistStarProgress()
            medalEngine.reconcile(with: self)
        }
    }

    /// Adds vocabulary from a completed stone. Module stones record only teach-screen words.
    private func recordWordsLearnedFromLesson(_ lesson: ASLLesson) {
        if lesson.type == .module {
            recordIntroducedWords(from: modulePlaySteps(for: lesson))
            return
        }
        guard !lesson.wordIds.isEmpty else { return }
        let previous = learnedWordIdsFromPath
        let updated = previous.union(lesson.wordIds)
        guard updated != previous else { return }
        learnedWordIdsFromPath = updated
        let delta = updated.subtracting(previous)
        refreshLearnedSignsCount()
        persistStarProgress()
        medalEngine.reconcile(with: self)
        scheduleQuizPreloadRefresh(delta: delta)
    }

    private func recordIntroducedWords(from steps: [ModulePlayStep]) {
        let ids = ModuleLessonView.introducedWordIds(in: steps)
        guard !ids.isEmpty else { return }
        let previousIntroduced = introducedWordIdsOnPath
        let previousPath = learnedWordIdsFromPath
        introducedWordIdsOnPath.formUnion(ids)
        learnedWordIdsFromPath.formUnion(ids)
        guard introducedWordIdsOnPath != previousIntroduced || learnedWordIdsFromPath != previousPath else { return }
        let delta = ids.subtracting(previousPath)
        invalidateAllModulePlayStepsCache()
        refreshLearnedSignsCount()
        persistStarProgress()
        medalEngine.reconcile(with: self)
        scheduleQuizPreloadRefresh(delta: delta)
    }

    /// Backfill path-learned and introduced signs from saved lesson progress once lesson metadata is available.
    private func reconcilePathLearnedWordsFromProgress() {
        let previousPath = learnedWordIdsFromPath
        let previousIntroduced = introducedWordIdsOnPath
        var pathIds = Set<String>()
        var introIds = Set<String>()
        var runningIntroduced = Set<String>()
        for lesson in allModuleLessonsInPathOrder() where lessonProgress(for: lesson.id) >= 1 {
            if lesson.type == .module {
                let steps = ModuleLessonView.buildPlaySteps(
                    for: lesson,
                    store: self,
                    introducedSoFar: runningIntroduced
                )
                let taught = ModuleLessonView.introducedWordIds(in: steps)
                runningIntroduced.formUnion(taught)
                introIds.formUnion(taught)
                pathIds.formUnion(taught)
            } else {
                pathIds.formUnion(lesson.wordIds)
            }
        }
        guard pathIds != previousPath || introIds != previousIntroduced else { return }
        learnedWordIdsFromPath = pathIds
        introducedWordIdsOnPath = introIds
        let delta = pathIds.subtracting(previousPath)
        invalidateAllModulePlayStepsCache()
        refreshLearnedSignsCount()
        persistStarProgress()
        medalEngine.reconcile(with: self)
        scheduleQuizPreloadRefresh(delta: delta)
    }

    private func loadLessonsForUnitsWithSavedProgress(in units: [ASLUnit]) {
        for unit in units {
            let prefix = unit.id + "-"
            let hasCompletedLesson = lessonProgressById.contains { key, progress in
                key.hasPrefix(prefix) && progress >= 1
            }
            if hasCompletedLesson {
                loadLessons(for: unit)
            }
        }
    }

    private func refreshLearnedSignsCount() {
        learnedSignsCount = studiedSignWordIds.count
    }

    @discardableResult
    func tryAwardStars(_ amount: Int, eventId: String) -> Int {
        guard amount > 0, !awardedStarEventIds.contains(eventId) else { return 0 }
        awardedStarEventIds.insert(eventId)
        totalStars += amount
        persistStarProgress()
        recordDailyActivityInternal()
        medalEngine.reconcile(with: self)
        return amount
    }

    /// Applies onboarding lesson stars and day-1 streak when the user starts a trial or subscription.
    func applyOnboardingTrialRewards(eventId: String = ASLPremiumAccess.onboardingStarEventId) {
        let awarded = tryAwardStars(
            ASLStarEconomy.onboardingLessonStarReward,
            eventId: eventId
        )
        if awarded == 0, dailyActivityStreak == 0 {
            recordDailyActivityInternal(suppressCelebration: true)
        }
        clearPendingDailyStreakCelebration()
    }

    private func updateDisplayStreak(_ sessionBest: Int) {
        guard sessionBest > displayStreak else { return }
        displayStreak = sessionBest
        persistStarProgress()
        medalEngine.reconcile(with: self)
    }

    private func loadStoredStarProgress() {
        guard
            let data = UserDefaults.standard.data(forKey: starsStorageKey),
            let snap = try? JSONDecoder().decode(StarProgressSnapshot.self, from: data)
        else { return }
        totalStars = max(0, snap.totalStars)
        displayStreak = max(0, snap.displayStreak)
        awardedStarEventIds = Set(snap.awardedEventIds)
        learnedWordIdsForStars = Set(snap.learnedWordIds)
        learnedWordIdsFromPath = Set(snap.pathLearnedWordIds ?? [])
        introducedWordIdsOnPath = Set(snap.introducedWordIdsOnPath ?? [])
        refreshLearnedSignsCount()
    }

    private func persistStarProgress() {
        let snap = StarProgressSnapshot(
            totalStars: totalStars,
            awardedEventIds: Array(awardedStarEventIds),
            learnedWordIds: Array(learnedWordIdsForStars),
            pathLearnedWordIds: Array(learnedWordIdsFromPath),
            introducedWordIdsOnPath: Array(introducedWordIdsOnPath),
            displayStreak: displayStreak
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: starsStorageKey)
        }
    }

    // MARK: - Daily activity streak

    private func loadDailyStreak() {
        guard
            let data = UserDefaults.standard.data(forKey: dailyStreakStorageKey),
            let snap = try? JSONDecoder().decode(DailyStreakSnapshot.self, from: data)
        else {
            dailyActivityStreak = 0
            bestDailyActivityStreak = 0
            lastActiveDayStartSince1970 = nil
            pendingDailyStreakCelebration = nil
            return
        }
        dailyActivityStreak = max(0, snap.streak)
        bestDailyActivityStreak = max(0, snap.bestStreak ?? snap.streak)
        lastActiveDayStartSince1970 = snap.lastDayStartSince1970
        activeDayKeys = Set(snap.activeDayKeys ?? [])
        pendingDailyStreakCelebration = snap.pendingCelebration
        if let pending = pendingDailyStreakCelebration {
            let todayKey = Self.dayKeyFormatter.string(from: Calendar.current.startOfDay(for: Date()))
            if pending.dayKey != todayKey {
                pendingDailyStreakCelebration = nil
                persistDailyStreak()
            }
        }
        if activeDayKeys.isEmpty, let lastT = lastActiveDayStartSince1970 {
            let key = Self.dayKeyFormatter.string(from: Date(timeIntervalSince1970: lastT))
            activeDayKeys.insert(key)
        }
        reconcileDailyStreakWithCalendar()
    }

    private func persistDailyStreak() {
        let snap = DailyStreakSnapshot(
            streak: dailyActivityStreak,
            bestStreak: bestDailyActivityStreak,
            lastDayStartSince1970: lastActiveDayStartSince1970,
            activeDayKeys: Array(activeDayKeys).sorted(),
            pendingCelebration: pendingDailyStreakCelebration
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: dailyStreakStorageKey)
        }
    }

    /// Call when the learner does meaningful work (lesson progress, stars, dictionary, unit complete).
    private func recordDailyActivityInternal(suppressCelebration: Bool = false) {
        reconcileDailyStreakWithCalendar()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayT = today.timeIntervalSince1970

        let todayKey = Self.dayKeyFormatter.string(from: today)
        activeDayKeys.insert(todayKey)
        if activeDayKeys.count > 90 {
            let sorted = activeDayKeys.sorted()
            activeDayKeys = Set(sorted.suffix(90))
        }

        if let lastT = lastActiveDayStartSince1970 {
            let lastStart = cal.startOfDay(for: Date(timeIntervalSince1970: lastT))
            if lastStart == today {
                persistDailyStreak()
                return
            }
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            let yesterdayStart = cal.startOfDay(for: yesterday)
            let previousStreak: Int
            let newStreak: Int
            if lastStart == yesterdayStart {
                previousStreak = dailyActivityStreak
                newStreak = dailyActivityStreak + 1
                dailyActivityStreak = newStreak
            } else {
                previousStreak = 0
                newStreak = 1
                dailyActivityStreak = 1
            }
            bestDailyActivityStreak = max(bestDailyActivityStreak, dailyActivityStreak)
            lastActiveDayStartSince1970 = todayT
            if !suppressCelebration {
                queueDailyStreakCelebration(previous: previousStreak, new: newStreak, dayKey: todayKey)
            } else {
                persistDailyStreak()
            }
        } else {
            dailyActivityStreak = 1
            bestDailyActivityStreak = max(bestDailyActivityStreak, dailyActivityStreak)
            lastActiveDayStartSince1970 = todayT
            if !suppressCelebration {
                queueDailyStreakCelebration(previous: 0, new: 1, dayKey: todayKey)
            } else {
                persistDailyStreak()
            }
        }
        medalEngine.reconcile(with: self)
    }

    private func queueDailyStreakCelebration(previous: Int, new: Int, dayKey: String) {
        pendingDailyStreakCelebration = DailyStreakCelebrationPayload(
            previousStreak: previous,
            newStreak: new,
            dayKey: dayKey
        )
        persistDailyStreak()
    }

    /// If the learner missed a full calendar day since last activity, clear the streak.
    private func reconcileDailyStreakWithCalendar() {
        guard let lastT = lastActiveDayStartSince1970 else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let yesterdayStart = cal.startOfDay(for: yesterday)
        let lastStart = cal.startOfDay(for: Date(timeIntervalSince1970: lastT))
        guard lastStart < yesterdayStart else { return }
        dailyActivityStreak = 0
        lastActiveDayStartSince1970 = nil
        persistDailyStreak()
    }
}

private struct LessonMediaPreloadState {
    var wordIds: [String] = []
}

private struct DeferredFreeRoamMediaRequest {
    let units: [ASLUnit]
    let priorityUnitIndices: [Int]
}

private struct LessonProgressSnapshot: Codable {
    let progress: Double
    let stepIndex: Int
}

private struct StarProgressSnapshot: Codable {
    var totalStars: Int
    var awardedEventIds: [String]
    var learnedWordIds: [String]
    var pathLearnedWordIds: [String]?
    var introducedWordIdsOnPath: [String]?
    var displayStreak: Int
}

private struct DailyStreakSnapshot: Codable {
    var streak: Int
    var bestStreak: Int?
    var lastDayStartSince1970: TimeInterval?
    var activeDayKeys: [String]?
    var pendingCelebration: DailyStreakCelebrationPayload?
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
