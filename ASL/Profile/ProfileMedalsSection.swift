//
//  ProfileMedalsSection.swift
//  ASL
//

import SwiftUI

struct ProfileMedalsSection: View {
    @ObservedObject var store: ASLDataStore
    @Binding var selectedMedal: ProfileMedalItem?
    var onShowAllMedals: () -> Void

    private var medalItems: [ProfileMedalItem] {
        store.medalEngine.previewMedals(from: store)
    }

    private var earnedCount: Int {
        store.medalEngine.earnedCount(from: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Haptics.tap()
                onShowAllMedals()
            } label: {
                HStack(spacing: 6) {
                    Text("Medals")
                        .aslStyle(.cardTitle, variant: .compact)
                        .fontWeight(.bold)

                    if earnedCount > 0 {
                        Text("\(earnedCount)")
                            .aslStyle(.cardDescription, variant: .prominent, color: Brand.primary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.asl(15, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View all medals, \(earnedCount) earned")

            if store.isLoadingUnits && medalItems.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if medalItems.isEmpty {
                Text("Complete lessons, build streaks, and practice to earn medals.")
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(medalItems) { item in
                            Button {
                                Haptics.tap()
                                selectedMedal = item
                            } label: {
                                ProfileMedalCell(
                                    item: item,
                                    showsLabel: true,
                                    usesFixedLabelSlot: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
