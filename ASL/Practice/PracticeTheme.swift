//
//  PracticeTheme.swift
//  ASL
//

import SwiftUI

enum PracticeTheme {
    /// Practice tab accent (matches `AppTab.practice` tint).
    static let accent = Color(red: 0.34, green: 0.73, blue: 0.55)
    static let accentShadow = Color(red: 0.23, green: 0.57, blue: 0.43)
    /// Timer urgency color (retained for potential timed practice features).
    static let timerUrgent = Color(red: 0.89, green: 0.17, blue: 0.17)
    static let leaveConfirmMessage = "You can leave anytime. This session won't resume."
}

struct PracticeHeader: View {
    private let mascotImageName = "spelling"

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabScreenHeaderTitleBlock(
                title: "Practice",
                subtitle: "Short daily practice to build fluency. Quiz, flip, and match.",
                mascotWidth: UnitMascot.headerMascotSize,
                toolbarTrailingReserve: 16
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(mascotImageName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UnitMascot.headerMascotSize, height: UnitMascot.headerMascotSize)
                    .padding(.trailing, TabScreenHeaderLayout.mascotTrailingPadding)
                    .padding(.top, TabScreenHeaderLayout.mascotTopPadding)
                    .offset(x: -14)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, 16)
        }
        .frame(height: TabScreenHeaderLayout.height)
    }
}
