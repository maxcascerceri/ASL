//
//  OnboardingMascotHeader.swift
//  ASL
//

import SwiftUI

struct OnboardingMascotHeader: View {
    var imageName: String = UnitMascot.stoneCompleteCelebrationImageName
    let bubbleText: String
    var boldRanges: [String] = []
    var imageSize: CGFloat = OnboardingMascotMetrics.headerMascotSize
    var bubbleAlignment: VerticalAlignment = .bottom

    var body: some View {
        HStack(alignment: bubbleAlignment, spacing: OnboardingMascotMetrics.headerSpacing) {
            mascotImage

            MascotSpeechBubble(
                text: bubbleText,
                boldRanges: boldRanges,
                tailDirection: .leading
            )
        }
        .padding(.horizontal, 4)
    }

    private var mascotImage: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize, height: imageSize)
    }
}
