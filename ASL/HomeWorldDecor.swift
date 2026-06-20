//
//  HomeWorldDecor.swift
//  ASL
//
//  Soft pastel sky background for the home journey (Step 1).
//

import SwiftUI

struct HomeWorldBackground: View {
    /// Single sky tone so the pinned header and scroll path read as one surface.
    static let lightSky = Color(red: 0.96, green: 0.98, blue: 1.0)

    var body: some View {
        Self.lightSky
    }
}

// MARK: - Dot grid

private enum HomeDotGridMetrics {
    static let spacing: CGFloat = 26
    static let dotRadius: CGFloat = 1.25
}

/// Subtle pegboard dots for the home scroll feed — structure without a literal path.
struct HomeDotGridBackground: View {
    private var dotColor: Color {
        Brand.divider.opacity(0.40)
    }

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let spacing = HomeDotGridMetrics.spacing
            let radius = HomeDotGridMetrics.dotRadius
            let columns = Int(ceil(size.width / spacing)) + 1
            let rows = Int(ceil(size.height / spacing)) + 1

            for row in 0..<rows {
                for column in 0..<columns {
                    let center = CGPoint(
                        x: CGFloat(column) * spacing + spacing / 2,
                        y: CGFloat(row) * spacing + spacing / 2
                    )
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Base chrome fill plus the home dot grid — used behind the scroll feed only.
struct HomeScrollSurfaceBackground: View {
    var body: some View {
        ZStack {
            Brand.homeBackground
            HomeDotGridBackground()
        }
    }
}
