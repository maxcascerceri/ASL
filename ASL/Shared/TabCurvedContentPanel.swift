//
//  TabCurvedContentPanel.swift
//  ASL
//

import SwiftUI

/// Shared insets and spacing for curved-panel tabs (Practice, Profile, Signs grid).
enum TabCurvedPanelLayout {
    static let contentTopInset: CGFloat = 20
    static let cardSpacing: CGFloat = 18
    static let contentBottomInset: CGFloat = 28
    /// Raised-card depth rim (matches `PracticeOptionCard` / `SignCategoryCard`).
    static let raisedCardDepth: CGFloat = PremiumCardMetrics.depth
}

/// Title + subtitle placement for Signs, Profile, and similar tab headers.
enum TabScreenHeaderLayout {
    static let height: CGFloat = 200
    static let titleTopPadding: CGFloat = 30
    static let titleLeadingPadding: CGFloat = 22
    static let titleSubtitleSpacing: CGFloat = 8
    /// Trailing space reserved for the header toolbar button.
    static let toolbarTrailingReserve: CGFloat = 56
    static let mascotTopPadding: CGFloat = 18
    static let mascotTrailingPadding: CGFloat = 4
    static let toolbarTopPadding: CGFloat = 8
    static let toolbarTrailingPadding: CGFloat = 16
}

struct TabScreenHeaderTitleBlock: View {
    let title: String
    let subtitle: String
    /// Width reserved for the header mascot so the title wraps like the Signs tab.
    var mascotWidth: CGFloat = 0
    /// Trailing space reserved for the header toolbar button (search, settings, etc.).
    var toolbarTrailingReserve: CGFloat = TabScreenHeaderLayout.toolbarTrailingReserve

    var body: some View {
        VStack(alignment: .leading, spacing: TabScreenHeaderLayout.titleSubtitleSpacing) {
            Text(title)
                .aslStyle(.tabScreenTitle, variant: .standard)

            Text(subtitle)
                .aslStyle(.subtitle, variant: .compact)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, TabScreenHeaderLayout.titleTopPadding)
        .padding(.leading, TabScreenHeaderLayout.titleLeadingPadding)
        .padding(
            .trailing,
            toolbarTrailingReserve
                + mascotWidth
                + TabScreenHeaderLayout.mascotTrailingPadding
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Top-rounded chrome sheet shared by Signs, Practice, and similar tabs.
struct TabCurvedContentPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private let topCornerRadius: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
            .fill(Brand.chrome)
            .elevation(.navigationPanel)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
            .stroke(Brand.divider.opacity(0.85), lineWidth: 1)
            .allowsHitTesting(false)
        }
    }
}
