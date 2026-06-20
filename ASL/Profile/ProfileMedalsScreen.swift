//
//  ProfileMedalsScreen.swift
//  ASL
//

import SwiftUI

struct ProfileMedalsScreen: View {
    @ObservedObject var store: ASLDataStore
    @Binding var selectedMedal: ProfileMedalItem?

    @Environment(\.dismiss) private var dismiss

    private var sections: [MedalSection] {
        store.medalEngine.medalsGrouped(from: store)
    }

    private var earnedCount: Int {
        store.medalEngine.earnedCount(from: store)
    }

    private var totalCount: Int {
        store.medalEngine.allMedals(from: store).count
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background {
                    Brand.canvas
                        .ignoresSafeArea(edges: .top)
                }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    if store.isLoadingUnits && sections.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if sections.isEmpty {
                        emptyState
                    } else {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .brandCanvasBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadUnitsIfNeeded()
            store.medalEngine.reconcile(with: store)
        }
    }

    private var header: some View {
        ZStack {
            Text("Medals")
                .aslStyle(.cardTitle, variant: .standard)

            HStack(alignment: .center, spacing: 0) {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.asl(16, weight: .semibold, design: .ui))
                        .foregroundStyle(Brand.secondaryLabel)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                if totalCount > 0 {
                    Text("\(earnedCount)/\(totalCount) earned")
                        .aslStyle(.progressLabel, variant: .prominent)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: MedalSection) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(section.title)
                .aslStyle(.cardTitle, variant: .compact)

            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(section.items) { item in
                    Button {
                        Haptics.tap()
                        selectedMedal = item
                    } label: {
                        ProfileMedalCell(
                            item: item,
                            discSize: 102,
                            iconSize: 40,
                            showsLabel: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "medal.fill")
                .font(.asl(36, weight: .semibold, design: .ui))
                .foregroundStyle(Brand.divider)

            Text("Your medal collection will appear here as you complete units, build streaks, and practice.")
                .aslStyle(.cardDescription, variant: .compact)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 12)
    }

    private func loadUnitsIfNeeded() {
        guard let path = store.paths.first else { return }
        store.loadUnits(for: path)
    }
}
