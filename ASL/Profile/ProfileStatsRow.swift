//
//  ProfileStatsRow.swift
//  ASL
//

import SwiftUI

struct ProfileStatsRow: View {
    @ObservedObject var store: ASLDataStore
    var onStarsTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ProfileStatCard(
                palette: .profileSigns,
                iconAnimation: .handsClap,
                value: store.learnedSignsCount,
                label: "Signs"
            )

            ProfileStatCard(
                palette: .profileStars,
                iconAnimation: .starTwinkle,
                value: store.totalStars,
                label: "Stars",
                animatesIcon: false,
                action: onStarsTap
            )
        }
    }
}
