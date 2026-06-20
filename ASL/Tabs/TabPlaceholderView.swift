//
//  TabPlaceholderView.swift
//  ASL
//

import SwiftUI

/// Minimal shell for tabs that do not have screens yet.
struct TabPlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Brand.textPrimary)
        } description: {
            Text("Screen design coming soon.")
                .foregroundStyle(Brand.secondaryLabel)
        }
        .brandCanvasBackground()
    }
}
