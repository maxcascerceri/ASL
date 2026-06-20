//
//  ContentView.swift
//  ASL
//
//  Created by Max Cascerceri on 5/5/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ASLDataStore
    @State private var selectedTab: AppTab = .home
    @State private var isCustomTabBarHidden = false
    @State private var lessonEntryRevealCoordinator = LessonEntryRevealCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    private var showsTabBar: Bool {
        !isCustomTabBarHidden && !lessonEntryRevealCoordinator.suppressesTabBar
    }

    var body: some View {
        VStack(spacing: 0) {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsTabBar {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .overlay {
            LessonEntryRevealOverlay(coordinator: lessonEntryRevealCoordinator)
                .zIndex(100)
        }
        .environment(lessonEntryRevealCoordinator)
        .background {
            if selectedTab == .home {
                Brand.homeBackground.ignoresSafeArea()
            } else {
                HomeWorldBackground().ignoresSafeArea()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onPreferenceChange(CustomTabBarHiddenPreferenceKey.self) { hidden in
            isCustomTabBarHidden = hidden
        }
        .task {
            await store.ensureHomeCurriculumLoaded()
            store.practiceDailyEngine.bind(store: store)
            store.medalEngine.reconcile(with: store)
            await store.warmBundledPlaybackCacheIfNeeded()
            await store.refreshQuizPreloadIfNeeded()
            #if DEBUG
            print("[BundledSignMedia] videos:", BundledSignMedia.bundledVideoWordIds.count)
            #endif
        }
        .onChange(of: store.pendingTabSelection) { _, tab in
            guard let tab else { return }
            selectedTab = tab
            store.acknowledgeTabSelection()
        }
        .onChange(of: store.practiceDailyEngine.navigation.shouldReturnToPractice) { _, shouldReturn in
            guard shouldReturn else { return }
            selectedTab = .practice
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .signs {
                store.setSignsTabActive(false)
            }
            refreshHomeHeaderStatsIfVisible()
        }
        .onChange(of: isCustomTabBarHidden) { _, _ in
            refreshHomeHeaderStatsIfVisible()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refreshQuizPreloadIfNeeded() }
        }
        .medalCelebrationPresenter(
            store: store,
            selectedTab: $selectedTab,
            isTabBarHidden: isCustomTabBarHidden
        )
        .dailyStreakCelebrationPresenter(
            store: store,
            isTabBarHidden: isCustomTabBarHidden
        )
        .foregroundStyle(Brand.textPrimary)
    }

    private func refreshHomeHeaderStatsIfVisible() {
        guard selectedTab == .home, showsTabBar else { return }
        store.refreshHomeHeaderStats()
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            HomeTabView(
                store: store,
                lessonEntryRevealCoordinator: lessonEntryRevealCoordinator
            )
                .background(Brand.homeBackground.ignoresSafeArea())
                .environment(\.homeStatsForeground, selectedTab == .home && showsTabBar)
        case .practice:
            PracticeTabView(store: store)
        case .signs:
            SignsTabView(store: store)
        case .profile:
            ProfileTabView(store: store)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ASLDataStore())
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case practice
    case signs
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .practice: return "Practice"
        case .signs: return "Signs"
        case .profile: return "Profile"
        }
    }

    var iconAsset: String {
        switch self {
        case .home: return "TabHome"
        case .practice: return "TabPractice"
        case .signs: return "TabSigns"
        case .profile: return "TabProfile"
        }
    }

    var tint: Color {
        switch self {
        case .home: return Color(red: 1.00, green: 0.59, blue: 0.00)
        case .practice: return Color(red: 1.00, green: 0.60, blue: 0.67)
        case .signs: return Brand.primary
        case .profile: return Color(red: 0.61, green: 0.54, blue: 0.98)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let selectionIndicatorWidth: CGFloat = 44
    private let selectionIndicatorHeight: CGFloat = 6
    private let topDividerHeight: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(maxWidth: .infinity)
                    .frame(height: topDividerHeight)

                selectionIndicator
                    .padding(.horizontal, 8)
            }
            .frame(height: selectionIndicatorHeight)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        Haptics.tap()
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 0) {
                            ASLTabIcon(
                                assetName: tab.iconAsset,
                                isSelected: selectedTab == tab
                            )
                            Text(tab.title)
                                .font(
                                    .asl(
                                        ASLTextMetrics.size(for: .tabBar, variant: .prominent),
                                        weight: selectedTab == tab ? .bold : .semibold
                                    )
                                )
                                .tracking(ASLTextMetrics.tracking(for: .tabBar))
                                .padding(.top, -4)
                                .padding(.bottom, -9)
                        }
                        .foregroundStyle(selectedTab == tab ? Brand.primary : Brand.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TabBarButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 0)
            .padding(.bottom, 0)
        }
        .safeAreaPadding(.bottom, -21)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .elevation(.navigationBar)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedTab)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var selectionIndicator: some View {
        GeometryReader { geo in
            let tabCount = CGFloat(AppTab.allCases.count)
            let tabWidth = geo.size.width / tabCount
            let selectedIndex = CGFloat(
                AppTab.allCases.firstIndex(of: selectedTab) ?? 0
            )
            let centerX = tabWidth * selectedIndex + tabWidth / 2

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: selectionIndicatorHeight / 2,
                bottomTrailingRadius: selectionIndicatorHeight / 2,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Brand.primary)
            .frame(width: selectionIndicatorWidth, height: selectionIndicatorHeight)
            .position(x: centerX, y: selectionIndicatorHeight / 2)
        }
        .frame(height: selectionIndicatorHeight)
        .allowsHitTesting(false)
    }
}

private struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(ASLIconMotion.tap, value: configuration.isPressed)
    }
}

struct CustomTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
