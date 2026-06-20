//
//  ProfileHeaderView.swift
//  ASL
//

import SwiftUI

struct ProfileHeaderView: View {
    let onSettings: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabScreenHeaderTitleBlock(
                title: "Profile",
                subtitle: "Your learning progress. Track your stats, streak, and the medals you've earned.",
                mascotWidth: UnitMascot.profileHeaderMascotSize
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(UnitMascot.headAndFaceImageName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: UnitMascot.profileHeaderMascotSize,
                        height: UnitMascot.profileHeaderMascotSize
                    )
                    .padding(.trailing, TabScreenHeaderLayout.mascotTrailingPadding)
                    .padding(.top, TabScreenHeaderLayout.mascotTopPadding)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, TabScreenHeaderLayout.toolbarTrailingReserve)

            Button {
                Haptics.tap()
                onSettings()
            } label: {
                ProfileGearButtonIcon()
                    .contentShape(Circle())
            }
            .buttonStyle(ProfileRaisedPressStyle())
            .padding(.top, TabScreenHeaderLayout.toolbarTopPadding)
            .padding(.trailing, TabScreenHeaderLayout.toolbarTrailingPadding)
            .zIndex(10)
        }
        .frame(height: TabScreenHeaderLayout.height)
    }
}

private struct ProfileGearButtonIcon: View {
    @Environment(\.profileRaisedPressed) private var isPressed

    var body: some View {
        ProfileRaisedCircleButton(
            isPressed: isPressed,
            size: 44,
            depth: 5,
            face: Brand.chrome,
            shadow: Brand.divider
        ) {
            ASLIcon(
                source: .symbol("gearshape.fill"),
                role: .toolbar,
                tint: Brand.primary
            )
        }
    }
}
