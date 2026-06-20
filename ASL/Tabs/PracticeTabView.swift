//
//  PracticeTabView.swift
//  ASL
//

import SwiftUI

struct PracticeTabView: View {
    @ObservedObject var store: ASLDataStore

    @State private var selectedLaunch: PracticeSessionLaunch?
    @State private var highlightedTaskKey: String?

    private var navigation: PracticeDailyNavigationCoordinator {
        store.practiceDailyEngine.navigation
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PracticeHeader()

                TabCurvedContentPanel {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: TabCurvedPanelLayout.cardSpacing) {
                                ForEach(PracticeMode.allCases) { mode in
                                    practiceModeRow(mode)
                                }

                                PracticeDailyPracticeSection(
                                    store: store,
                                    highlightedTaskKey: highlightedTaskKey
                                )
                                .id("dailyPracticeSection")
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, TabCurvedPanelLayout.contentTopInset)
                            .padding(.bottom, TabCurvedPanelLayout.contentBottomInset)
                        }
                        .onChange(of: navigation.highlightedTaskInstanceKey) { _, key in
                            guard let key else { return }
                            highlightedTaskKey = key
                            withAnimation(.easeInOut(duration: 0.45)) {
                                proxy.scrollTo(key, anchor: .center)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                highlightedTaskKey = nil
                                navigation.clearHighlight()
                            }
                        }
                    }
                }
                .padding(.top, -12)
            }
            .brandCanvasBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.practiceDailyEngine.refreshForToday(store: store)
                Task { await store.refreshQuizPreloadIfNeeded() }
                handlePendingPracticeLaunch()
                if let launch = store.consumePendingPracticeLaunch() {
                    selectedLaunch = launch
                }
            }
            .onChange(of: navigation.consumePracticeLaunch) { _, launch in
                guard launch != nil else { return }
                handlePendingPracticeLaunch()
            }
            .onChange(of: navigation.shouldReturnToPractice) { _, shouldReturn in
                if shouldReturn, navigation.highlightedTaskInstanceKey != nil {
                    navigation.acknowledgeReturnToPractice()
                }
            }
            .navigationDestination(item: $selectedLaunch) { launch in
                practiceDestination(for: launch)
                    .environment(\.lessonPortalDismiss) {
                        selectedLaunch = nil
                    }
            }
        }
    }

    @ViewBuilder
    private func practiceModeRow(_ mode: PracticeMode) -> some View {
        let isEnabled: Bool = {
            switch mode {
            case .quiz:
                return PracticeWordPool.isQuizAvailable(from: store)
            case .vocabularyMatch:
                return PracticeWordPool.isVocabularyMatchAvailable(from: store)
            case .spellYourName:
                return PracticeSpellYourNameAvailability.isUnlocked(from: store)
            default:
                return !PracticeWordPool.wordIds(for: mode, store: store).isEmpty
            }
        }()

        PracticeOptionCard(mode: mode, isEnabled: isEnabled, isPreparing: false) {
            guard isEnabled else { return }
            Haptics.tap()
            selectedLaunch = PracticeSessionLaunch(
                mode: mode,
                wordIds: [],
                unitId: nil
            )
        }
    }

    private func handlePendingPracticeLaunch() {
        guard let launch = navigation.consumePracticeLaunch else { return }
        navigation.acknowledgePracticeLaunchConsumed()
        selectedLaunch = launch
    }

    @ViewBuilder
    private func practiceDestination(for launch: PracticeSessionLaunch) -> some View {
        let pool = launch.wordIds.isEmpty
            ? PracticeWordPool.wordIds(for: launch.mode, store: store)
            : launch.wordIds

        if launch.mode == .quiz,
           !PracticeQuizCatalog.isAvailable(from: store) {
            PracticeUnavailableView(mode: .quiz)
        } else if launch.mode == .spellYourName,
                  !PracticeSpellYourNameAvailability.isUnlocked(from: store) {
            PracticeUnavailableView(mode: .spellYourName)
        } else {
            switch launch.mode {
            case .quiz:
                PracticeQuizView(store: store, wordIds: pool, sourceUnitId: launch.unitId)
            case .flashcards:
                PracticeFlashcardsView(store: store, wordIds: pool, sourceUnitId: launch.unitId)
            case .vocabularyMatch:
                PracticeVocabularyMatchingView(store: store, pool: pool)
            case .spellYourName:
                PracticeSpellYourNameView(
                    store: store,
                    initialEntry: launch.spellEntry,
                    initialIntent: launch.spellIntent ?? .personalName,
                    skipEntry: launch.spellEntry != nil
                )
            }
        }
    }
}
