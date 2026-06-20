//
//  SectionDivider.swift
//  ASL
//

import SwiftUI

/// Centered title with horizontal rules (home phase headers, profile sections).
struct SectionDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Brand.divider)
                .frame(height: 1)
            Text(title)
                .aslStyle(.sectionTitle)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.opacity)
            Rectangle()
                .fill(Brand.divider)
                .frame(height: 1)
        }
    }
}
