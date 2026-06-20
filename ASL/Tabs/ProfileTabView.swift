//
//  ProfileTabView.swift
//  ASL
//

import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var store: ASLDataStore

    @State private var showSettings = false
    @State private var showStarsInfo = false
    @State private var showMedalsScreen = false
    @State private var selectedMedal: ProfileMedalItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileHeaderView {
                    showSettings = true
                }

                TabCurvedContentPanel {
                    VStack(spacing: TabCurvedPanelLayout.cardSpacing) {
                        ProfileStatsRow(store: store) {
                            showStarsInfo = true
                        }

                        ProfileStreakHeroCard(store: store)

                        ProfileMedalsSection(
                            store: store,
                            selectedMedal: $selectedMedal,
                            onShowAllMedals: {
                                showMedalsScreen = true
                            }
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, TabCurvedPanelLayout.contentTopInset)
                    .padding(.bottom, TabCurvedPanelLayout.contentBottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.top, -12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .brandCanvasBackground()
            .onAppear {
                store.refreshDailyStreakIfNeeded()
                loadUnitsIfNeeded()
                store.medalEngine.reconcile(with: store)
            }
            .task(id: store.paths.first?.id) {
                loadUnitsIfNeeded()
            }
            .sheet(isPresented: $showSettings) {
                ProfileSettingsSheet()
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStarsInfo) {
                ProfileStarsInfoSheet(store: store)
            }
            .sheet(item: $selectedMedal) { item in
                ProfileMedalDetailSheet(item: item, store: store)
            }
            .navigationDestination(isPresented: $showMedalsScreen) {
                ProfileMedalsScreen(
                    store: store,
                    selectedMedal: $selectedMedal
                )
            }
        }
    }

    private func loadUnitsIfNeeded() {
        guard let path = store.paths.first else { return }
        store.loadUnits(for: path)
    }
}
